const std = @import("std");
const zlua = @import("zlua");
const common = @import("../../common.zig");
const Luau = zlua.Lua;
const wrap = zlua.wrap;
const LuauTry = common.luau.loader.LuauTry;
const luauError = common.luau.loader.luauError;
const logger = common.luau.loader.logger;

var config_map_ptr: ?*std.StringHashMap([]const u8) = null;

///Sends the exported functions to luau.
pub fn load_export(luau: *Luau, config_ptr: *std.StringHashMap([]const u8)) void {
    luau.pushFunction(wrap(print_fn));
    luau.setGlobal("print");
    luau.pushFunction(wrap(error_fn));
    luau.setGlobal("error");
    luau.pushFunction(wrap(getenv_fn));
    luau.setGlobal("getenv");
    config_map_ptr = config_ptr;
    luau.pushFunction(wrap(getcfg_fn));
    luau.setGlobal("getcfg");
    luau.pushFunction(wrap(sanitizetoascii_fn));
    luau.setGlobal("sanitizetoascii");
}

const print_logger = std.log.scoped(.luau_print);

fn appendu8SliceOrLog(allocator: std.mem.Allocator, array_list: *std.ArrayList(u8), slice: []const u8) void {
    if (array_list.appendSlice(allocator, slice)) {} else |e| {
        print_logger.err("Error appending slice to buffer. Slice: {s}, Err: {t}", .{ slice, e });
    }
}

fn printAtIndex(luau: *Luau, i: i32, print_list: *std.ArrayList(u8), allocator: std.mem.Allocator) void {
    switch (luau.typeOf(i)) {
        .none => {
            appendu8SliceOrLog(allocator, print_list, "None ");
        },
        .nil => {
            appendu8SliceOrLog(allocator, print_list, "Nill ");
        },
        .string => {
            const val = luau.toString(i) catch "Error";
            appendu8SliceOrLog(allocator, print_list, std.fmt.allocPrint(allocator, "{s} ", .{val}) catch "Error");
        },
        .number => {
            const val = luau.toNumber(i) catch 0.0;
            appendu8SliceOrLog(allocator, print_list, std.fmt.allocPrint(allocator, "{d} ", .{val}) catch "Error");
        },
        .boolean => {
            const val = luau.toBoolean(i);
            appendu8SliceOrLog(allocator, print_list, std.fmt.allocPrint(allocator, "{} ", .{val}) catch "Error");
        },
        .table => {
            appendu8SliceOrLog(allocator, print_list, "{ ");
            luau.pushNil();
            while (luau.next(i)) {
                const key_index = luau.getTop() - 1;
                const val_index = luau.getTop();

                const key_type = luau.typeOf(key_index);

                switch (key_type) {
                    .string => {
                        appendu8SliceOrLog(allocator, print_list, std.fmt.allocPrint(allocator, "{s}=", .{luau.toString(-2) catch "Error"}) catch "Error");
                    },
                    .number => {
                        appendu8SliceOrLog(allocator, print_list, std.fmt.allocPrint(allocator, "{d}=", .{luau.toInteger(-2) catch 0}) catch "Error");
                    },
                    else => {
                        appendu8SliceOrLog(allocator, print_list, "Error");
                    },
                }
                printAtIndex(luau, val_index, print_list, allocator);
                luau.pop(1);
            }
            appendu8SliceOrLog(allocator, print_list, "} ");
        },
        else => {
            appendu8SliceOrLog(allocator, print_list, std.fmt.allocPrint(allocator, "<{s}> ", .{luau.typeNameIndex(i)}) catch "Error");
        },
    }
}

fn sanitizeSlice(
    allocator: std.mem.Allocator,
    str: []const u8,
) ![]const u8 {
    const view = try std.unicode.Utf8View.init(str);
    var itr = view.iterator();

    var cleaned_string = std.ArrayList(u8).empty;
    defer cleaned_string.deinit(allocator);
    try cleaned_string.ensureTotalCapacity(allocator, str.len);

    while (itr.nextCodepoint()) |codepoint| {
        const replace_char = switch (codepoint) {
            //Degrees
            '°' => '*',
            //Upside down explanation point
            '¡' => '!',
            //Quotes
            '“' => '"',
            '”' => '"',
            '„' => '"',
            '‟' => '"',
            '‘' => '\'',
            '’' => '\'',
            '‚' => '\'',
            '‛' => '\'',
            //Dashes
            '‐' => '-',
            '-' => '-',
            '‒' => '-',
            '–' => '-',
            '—' => '-',
            '―' => '-',
            '−' => '-',
            //A
            'À', 'Á', 'Â', 'Ã', 'Ä', 'Å', 'Ā', 'Ă', 'Ą' => 'A',
            'à', 'á', 'â', 'ã', 'ä', 'å', 'ā', 'ă', 'ą' => 'a',
            //AE
            'Æ' => 'A',
            'æ' => 'a',
            //C
            'Ç', 'Ć', 'Ĉ', 'Ċ', 'Č' => 'C',
            'ç', 'ć', 'ĉ', 'ċ', 'č' => 'c',
            //D
            'Ð', 'Ď', 'Đ' => 'D',
            'ð', 'ď', 'đ' => 'd',
            //E
            'È', 'É', 'Ê', 'Ë', 'Ē', 'Ĕ', 'Ė', 'Ę', 'Ě' => 'E',
            'è', 'é', 'ê', 'ë', 'ē', 'ĕ', 'ė', 'ę', 'ě' => 'e',
            //G
            'Ĝ', 'Ğ', 'Ġ', 'Ģ' => 'G',
            'ĝ', 'ğ', 'ġ', 'ģ' => 'g',
            //H
            'Ĥ', 'Ħ' => 'H',
            'ĥ', 'ħ' => 'h',
            //I
            'Ì', 'Í', 'Î', 'Ï', 'Ĩ', 'Ī', 'Ĭ', 'Į', 'İ' => 'I',
            'ì', 'í', 'î', 'ï', 'ĩ', 'ī', 'ĭ', 'į', 'ı' => 'i',
            //J
            'Ĵ' => 'J',
            'ĵ' => 'j',
            //K
            'Ķ' => 'K',
            'ķ' => 'k',
            //L
            'Ĺ', 'Ļ', 'Ľ', 'Ŀ', 'Ł' => 'L',
            'ĺ', 'ļ', 'ľ', 'ŀ', 'ł' => 'l',
            //N
            'Ñ', 'Ń', 'Ņ', 'Ň' => 'N',
            'ñ', 'ń', 'ņ', 'ň', 'ŉ' => 'n',
            //O
            'Ò', 'Ó', 'Ô', 'Õ', 'Ö', 'Ø', 'Ō', 'Ŏ', 'Ő' => 'O',
            'ò', 'ó', 'ô', 'õ', 'ö', 'ø', 'ō', 'ŏ', 'ő' => 'o',
            //OE
            'Œ' => 'O',
            'œ' => 'o',
            //R
            'Ŕ', 'Ŗ', 'Ř' => 'R',
            'ŕ', 'ŗ', 'ř' => 'r',
            //S
            'Ś', 'Ŝ', 'Ş', 'Š' => 'S',
            'ś', 'ŝ', 'ş', 'š', 'ß' => 's',
            //T
            'Ţ', 'Ť', 'Ŧ' => 'T',
            'ţ', 'ť', 'ŧ' => 't',
            //U
            'Ù', 'Ú', 'Û', 'Ü', 'Ũ', 'Ū', 'Ŭ', 'Ů', 'Ű', 'Ų' => 'U',
            'ù', 'ú', 'û', 'ü', 'ũ', 'ū', 'ŭ', 'ů', 'ű', 'ų' => 'u',
            //W
            'Ŵ' => 'W',
            'ŵ' => 'w',
            //Y
            'Ý', 'Ŷ', 'Ÿ' => 'Y',
            'ý', 'ÿ', 'ŷ' => 'y',
            //Z
            'Ź', 'Ż', 'Ž' => 'Z',
            'ź', 'ż', 'ž' => 'z',

            else => codepoint,
        };

        var buffer: [7]u8 = undefined;
        const char_len = try std.unicode.utf8Encode(replace_char, &buffer);
        try cleaned_string.appendSlice(allocator, buffer[0..char_len]);
    }
    return try cleaned_string.toOwnedSlice(allocator);
}

///(Luau)
///Prints the given Luau args.
fn print_fn(luau: *Luau) i32 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var print_list = std.ArrayList(u8).empty;

    const arg_count: u31 = @max(0, luau.getTop());
    //Luau indexing starts at 1 (WTF)
    for (1..arg_count + 1) |i_usize| {
        const i: i32 = @intCast(i_usize);
        printAtIndex(luau, i, &print_list, arena.allocator());
    }
    print_logger.info("{s}", .{print_list.items});

    return 0;
}

///(Luau)
///Throws a luau error with the given error message.
fn error_fn(luau: *Luau) i32 {
    const message = luau.checkString(1);

    print_logger.err("{s}", .{message});
    luauError(luau, message);

    return 0;
}

///(Luau)
///Attempts to get a variable from the program's environment variables, if there is none returns nil.
fn getenv_fn(luau: *Luau) i32 {
    const key = luau.checkString(1)[0..];

    if (!std.unicode.utf8ValidateSlice(key)) luauError(luau, "Invalid path format: must be UTF-8");
    const allocator = std.heap.page_allocator;

    const has_var = std.process.hasEnvVar(allocator, key) catch luauError(luau, "Memory error or formatting error with hasEnvVar.");

    if (!has_var) {
        luau.pushNil();
        return 1;
    }

    const value = std.process.getEnvVarOwned(allocator, key) catch |e| {
        logger.err("Error attempting to get environment variable: {t}", .{e});
        luauError(luau, "Error attempting to get environment variable.");
    };

    _ = luau.pushString(value);

    return 1;
}

///(Luau)
///Attempts to get a variable from the clock's config key value store, if there is none returns nil.
fn getcfg_fn(luau: *Luau) i32 {
    const key = luau.checkString(1)[0..];

    if (!std.unicode.utf8ValidateSlice(key)) luauError(luau, "Invalid path format: must be UTF-8");

    if (config_map_ptr == null) luauError(luau, "Error loading clock config!");

    if (config_map_ptr.?.get(key)) |value| {
        _ = luau.pushString(value);
    } else {
        luau.pushNil();
        return 1;
    }

    return 1;
}

///(Luau)
///Replaces UTF8 characters to their ASCII equivalents for the given string.
fn sanitizetoascii_fn(luau: *Luau) i32 {
    const str = luau.checkString(1)[0..];
    const cleaned_string = sanitizeSlice(luau.allocator(), str) catch |e| {
        luauError(luau, "Error sanitizing to ASCII characters!");
        logger.err("{t}", .{e});
    };

    _ = luau.pushString(cleaned_string);
    defer luau.allocator().free(cleaned_string);
    return 1;
}

test "sanitizeSlice with accents" {
    // Thanks AI for the example
    const text = "“C’était déjà l’été — a naïve fiancé whispered: ‘¡Qué día tan fantástico!’ — while coöperating with his über-cool collègue – who noted: ‘Smörgåsbord ‒ voilà!’ — and added, “façade, rôle, piñata, crème brûlée — all-in-one test.””";
    const sanitized = try sanitizeSlice(std.testing.allocator, text);
    defer std.testing.allocator.free(sanitized);
    try std.testing.expectEqualStrings("\"C'etait deja l'ete - a naive fiance whispered: '!Que dia tan fantastico!' - while cooperating with his uber-cool collegue - who noted: 'Smorgasbord - voila!' - and added, \"facade, role, pinata, creme brulee - all-in-one test.\"\"", sanitized);
}

test "sanitizeSlice without accents" {
    const text = "the quick brown fox jumps over the lazy dog";
    const sanitized = try sanitizeSlice(std.testing.allocator, text);
    defer std.testing.allocator.free(sanitized);
    try std.testing.expectEqualStrings(text, sanitized);
}

test "sanitizeSlice empty slice" {
    const text = "";
    const sanitized = try sanitizeSlice(std.testing.allocator, text);
    defer std.testing.allocator.free(sanitized);
    try std.testing.expectEqualStrings(text, sanitized);
}
