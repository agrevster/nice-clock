const std = @import("std");
const zlua = @import("zlua");
const common = @import("../../common.zig");
const Luau = zlua.Lua;
const wrap = zlua.wrap;
const LuauTry = common.luau.loader.LuauTry;
const luauError = common.luau.loader.luauError;
const logger = common.luau.loader.logger;

///Sends the exported functions to luau.
pub fn load_export(luau: *Luau) void {
    luau.pushFunction(wrap(print_fn));
    luau.setGlobal("print");
    luau.pushFunction(wrap(error_fn));
    luau.setGlobal("error");
    luau.pushFunction(wrap(getenv_fn));
    luau.setGlobal("getenv");
}

const print_logger = std.log.scoped(.luau_print);

fn appendu8SliceOrLog(array_list: *std.ArrayList(u8), slice: []const u8) void {
    if (array_list.appendSlice(slice)) {} else |e| {
        print_logger.err("Error appending slice to buffer. Slice: {s}, Err: {s}", .{ slice, @errorName(e) });
    }
}

fn printAtIndex(luau: *Luau, i: i32, print_list: *std.ArrayList(u8), allocator: std.mem.Allocator) void {
    switch (luau.typeOf(i)) {
        .none => {
            appendu8SliceOrLog(print_list, "None ");
        },
        .nil => {
            appendu8SliceOrLog(print_list, "Nill ");
        },
        .string => {
            const val = luau.toString(i) catch "Error";
            appendu8SliceOrLog(print_list, std.fmt.allocPrint(allocator, "{s} ", .{val}) catch "Error");
        },
        .number => {
            const val = luau.toNumber(i) catch 0.0;
            appendu8SliceOrLog(print_list, std.fmt.allocPrint(allocator, "{d} ", .{val}) catch "Error");
        },
        .boolean => {
            const val = luau.toBoolean(i);
            appendu8SliceOrLog(print_list, std.fmt.allocPrint(allocator, "{} ", .{val}) catch "Error");
        },
        .table => {
            appendu8SliceOrLog(print_list, "{ ");
            luau.pushNil();
            while (luau.next(i)) {
                const key_index = luau.getTop() - 1;
                const val_index = luau.getTop();

                const key_type = luau.typeOf(key_index);

                switch (key_type) {
                    .string => {
                        appendu8SliceOrLog(print_list, std.fmt.allocPrint(allocator, "{s}=", .{luau.toString(-2) catch "Error"}) catch "Error");
                    },
                    .number => {
                        appendu8SliceOrLog(print_list, std.fmt.allocPrint(allocator, "{d}=", .{luau.toInteger(-2) catch 0}) catch "Error");
                    },
                    else => {
                        appendu8SliceOrLog(print_list, "Error");
                    },
                }
                printAtIndex(luau, val_index, print_list, allocator);
                luau.pop(1);
            }
            appendu8SliceOrLog(print_list, "} ");
        },
        else => {
            appendu8SliceOrLog(print_list, std.fmt.allocPrint(allocator, "<{s}> ", .{luau.typeNameIndex(i)}) catch "Error");
        },
    }
}

///(Luau)
///Prints the given Luau args.
fn print_fn(luau: *Luau) i32 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var print_list = std.ArrayList(u8).init(arena.allocator());

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
///Attempts to get a variable from the endowment, if there is none returns nil.
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
        logger.err("Error attempting to get environment variable: {s}", .{@errorName(e)});
        luauError(luau, "Error attempting to get environment variable.");
    };

    _ = luau.pushString(value);

    return 1;
}
