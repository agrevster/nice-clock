const std = @import("std");
const startsWith = std.mem.startsWith;
const parseInt = std.fmt.parseInt;

///A BDF Font
///To load a font call `parseBDF` and be sure to call `deinit` when you're finished.
pub const BDF = struct {
    width: u8,
    height: u8,
    default_char: u16,
    glyphs: std.AutoHashMap(u16, []u8),

    pub fn deinit(self: *BDF, allocator: std.mem.Allocator) void {
        var it = self.glyphs.valueIterator();
        while (it.next()) |glyph| {
            allocator.free(glyph.*);
        }
        self.glyphs.deinit();
    }

    ///Parsed a BDF font file into a `BDF` struct.
    pub fn parseBDF(allocator: std.mem.Allocator, input: []const u8) !BDF {
        var lines = std.mem.tokenizeSequence(u8, input, "\n");

        var width: u8 = 0;
        var height: u8 = 0;
        var default_char: u16 = 0;

        var glyphs = std.AutoHashMap(u16, []u8).init(allocator);

        var current_char: ?u16 = null;
        var in_bitmap = false;
        var bitmap = std.ArrayList(u8).init(allocator);

        // If there is an error be sure to free everything
        errdefer {
            var it = glyphs.valueIterator();
            while (it.next()) |glyph| {
                allocator.free(glyph.*);
            }
            glyphs.deinit();
            bitmap.deinit();
        }

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \r\n");
            if (startsWith(u8, trimmed, "FONTBOUNDINGBOX ")) {
                var values = std.mem.tokenizeSequence(u8, trimmed[16..], " ");
                width = try parseInt(u8, values.next().?, 10);
                height = try parseInt(u8, values.next().?, 10);
            } else if (startsWith(u8, trimmed, "DEFAULT_CHAR ")) {
                default_char = try parseInt(u16, trimmed[13..], 10);
            } else if (startsWith(u8, trimmed, "ENCODING ")) {
                current_char = try parseInt(u16, trimmed[9..], 10);
            } else if (startsWith(u8, trimmed, "CHARS ")) {
                try glyphs.ensureTotalCapacity(try parseInt(u16, trimmed[6..], 10));
            } else if (std.mem.eql(u8, trimmed, "BITMAP")) {
                in_bitmap = true;
                bitmap.clearRetainingCapacity();
            } else if (std.mem.eql(u8, trimmed, "ENDCHAR")) {
                if (current_char) |char| {
                    try glyphs.put(char, try bitmap.toOwnedSlice());
                }
                current_char = null;
                in_bitmap = false;
            } else if (in_bitmap) {
                const bytes = try parseInt(u16, trimmed, 16);
                const num_bytes = (trimmed.len + 1) / 2;
                for (0..num_bytes) |i| {
                    const shift: u4 = @intCast(8 * (num_bytes - 1 - i));
                    const byte: u8 = @intCast((bytes >> shift) & 0xFF);
                    try bitmap.append(byte);
                }
            }
        }

        return BDF{
            .width = width,
            .height = height,
            .default_char = default_char,
            .glyphs = glyphs,
        };
    }
};

test {
    const font_input =
        \\STARTFONT 2.1
        \\COMMENT $Id: 6x12.bdf,v 1.32 2008-06-26 12:50:43+01 mgk25 Rel $
        \\COMMENT Send bug reports to Markus Kuhn <http://www.cl.cam.ac.uk/~mgk25/>
        \\FONT -Misc-Fixed-Medium-R-SemiCondensed--12-110-75-75-C-60-ISO10646-1
        \\SIZE 12 75 75
        \\FONTBOUNDINGBOX 6 12 0 -2
        \\STARTPROPERTIES 22
        \\FONTNAME_REGISTRY ""
        \\FOUNDRY "Misc"
        \\FAMILY_NAME "Fixed"
        \\WEIGHT_NAME "Medium"
        \\SLANT "R"
        \\SETWIDTH_NAME "SemiCondensed"
        \\ADD_STYLE_NAME ""
        \\PIXEL_SIZE 12
        \\POINT_SIZE 120
        \\RESOLUTION_X 75
        \\RESOLUTION_Y 75
        \\SPACING "C"
        \\AVERAGE_WIDTH 60
        \\CHARSET_REGISTRY "ISO10646"
        \\CHARSET_ENCODING "1"
        \\FONT_ASCENT 10
        \\FONT_DESCENT 2
        \\DEFAULT_CHAR 0
        \\COPYRIGHT "Public domain terminal emulator font.  Share and enjoy."
        \\CAP_HEIGHT 7
        \\X_HEIGHT 5
        \\_GBDFED_INFO "Edited with gbdfed 1.3."
        \\ENDPROPERTIES
        \\CHARS 4531
        \\STARTCHAR char0
        \\ENCODING 0
        \\SWIDTH 480 0
        \\DWIDTH 6 0
        \\BBX 6 12 0 -2
        \\BITMAP
        \\00
        \\00
        \\00
        \\A8
        \\00
        \\88
        \\00
        \\88
        \\00
        \\A8
        \\00
        \\00
        \\ENDCHAR
        \\STARTCHAR plus
        \\ENCODING 43
        \\SWIDTH 480 0
        \\DWIDTH 6 0
        \\BBX 6 12 0 -2
        \\BITMAP
        \\00
        \\00
        \\00
        \\00
        \\20
        \\20
        \\F8
        \\20
        \\20
        \\00
        \\00
        \\00
        \\ENDCHAR
    ;
    var font = try BDF.parseBDF(std.testing.allocator, font_input);
    defer font.deinit(std.testing.allocator);
    std.debug.print("\n\nFONT WIDTH x HEIGHT: {d} x {d}\n", .{ font.width, font.height });
    std.debug.print("DEFAULT_CHAR: {b}\n", .{font.default_char});
    std.debug.print("Glyphs Capacity: {d}\n", .{font.glyphs.capacity()});

    try std.testing.expect(font.width == 6);
    try std.testing.expect(font.height == 12);
    try std.testing.expect(font.default_char == 0);

    const glyph = font.glyphs.get(0).?;

    const bytes_per_row = (font.width + 7) / 8;

    for (0..font.height) |row| {
        const row_start = row * bytes_per_row;
        const row_end = row_start + bytes_per_row;
        const row_bytes = glyph[row_start..row_end];

        var tile_index: u8 = 0;
        for (row_bytes) |byte| {
            for (0..8) |bit| {
                if (tile_index >= font.width) break;
                const bit_u3: u3 = @intCast(bit);
                if ((byte & (@as(u8, 0x80) >> bit_u3)) != 0) {
                    std.debug.print("#", .{});
                } else {
                    std.debug.print(".", .{});
                }
                tile_index += 1;
            }
        }
        std.debug.print("\n", .{});
    }
}

test "big font" {
    const font_input =
        \\FONT -misc-spleen-medium-r-normal--24-240-72-72-C-120-ISO10646-1
        \\SIZE 24 72 72
        \\FONTBOUNDINGBOX 12 24 0 -5
        \\STARTPROPERTIES 20
        \\FAMILY_NAME "Spleen"
        \\WEIGHT_NAME "Medium"
        \\FONT_VERSION "2.1.0"
        \\FOUNDRY "misc"
        \\SLANT "R"
        \\SETWIDTH_NAME "Normal"
        \\PIXEL_SIZE 24
        \\POINT_SIZE 240
        \\RESOLUTION_X 72
        \\RESOLUTION_Y 72
        \\SPACING "C"
        \\AVERAGE_WIDTH 120
        \\CHARSET_REGISTRY "ISO10646"
        \\CHARSET_ENCODING "1"
        \\MIN_SPACE 12
        \\FONT_ASCENT 19
        \\FONT_DESCENT 5
        \\COPYRIGHT "Copyright (c) 2018-2024, Frederic Cambus"
        \\DEFAULT_CHAR 32
        \\_GBDFED_INFO "Edited with gbdfed 1.6."
        \\ENDPROPERTIES
        \\CHARS 916
        \\STARTCHAR SPACE
        \\ENCODING 32
        \\SWIDTH 500 0
        \\DWIDTH 12 0
        \\BBX 12 24 0 -5
        \\BITMAP
        \\0000
        \\0000
        \\0000
        \\0000
        \\0000
        \\0000
        \\0000
        \\0000
        \\0000
        \\0000
        \\0000
        \\0000
        \\0000
        \\0000
        \\0000
        \\0000
        \\0000
        \\0000
        \\0000
        \\0000
        \\0000
        \\0000
        \\0000
        \\0000
        \\ENDCHAR
        \\STARTCHAR EXCLAMATION MARK
        \\ENCODING 33
        \\SWIDTH 500 0
        \\DWIDTH 12 0
        \\BBX 12 24 0 -5
        \\BITMAP
        \\0000
        \\0000
        \\0000
        \\0000
        \\0600
        \\0600
        \\0600
        \\0600
        \\0600
        \\0600
        \\0600
        \\0600
        \\0600
        \\0600
        \\0600
        \\0000
        \\0000
        \\0600
        \\0600
        \\0000
        \\0000
        \\0000
        \\0000
        \\0000
        \\ENDCHAR
    ;
    var font = try BDF.parseBDF(std.testing.allocator, font_input);
    defer font.deinit(std.testing.allocator);
    std.debug.print("\n\nFONT WIDTH x HEIGHT: {d} x {d}\n", .{ font.width, font.height });
    std.debug.print("DEFAULT_CHAR: {d}\n", .{font.default_char});
    std.debug.print("Glyphs Capacity: {d}\n", .{font.glyphs.capacity()});

    try std.testing.expect(font.width == 12);
    try std.testing.expect(font.height == 24);
    try std.testing.expect(font.default_char == 32);

    const glyph = font.glyphs.get('!').?;

    const bytes_per_row = (font.width + 7) / 8;

    for (0..font.height) |row| {
        const row_start = row * bytes_per_row;
        const row_end = row_start + bytes_per_row;
        const row_bytes = glyph[row_start..row_end];

        var tile_index: u8 = 0;
        for (row_bytes) |byte| {
            for (0..8) |bit| {
                if (tile_index >= font.width) break;
                const bit_u3: u3 = @intCast(bit);
                if ((byte & (@as(u8, 0x80) >> bit_u3)) != 0) {
                    std.debug.print("#", .{});
                } else {
                    std.debug.print(".", .{});
                }
                tile_index += 1;
            }
        }
        std.debug.print("\n", .{});
    }
}

///This enum is used to own and store all the BDF fonts used by the clock.
///Each field in the enum corresponds to a file in `./assets/fonts`
///Example: **Font5x8** = `./assets/fonts/5x8.bdf`
///To add a new font simply add a new enum field with the name of the new font you want added.
///`init` loads all the fonts *(this is expensive)* and when you're done with them run `deinit`.
pub const FontStore = enum {
    Font5x8,
    Font5x8_2,
    Font6x12,
    Font6x13,
    Font7x13,
    Font7x14,
    Font12x24,

    pub const FontStoreError = error{ FontStoreNotInitialized, FontStoreAlreadyInitialized };

    var fonts: [@typeInfo(FontStore).@"enum".fields.len]BDF = undefined;
    var fonts_initalized = false;

    ///Returns a loaded BDF font for the enum field owned by the font store.
    pub fn font(self: FontStore) FontStoreError!BDF {
        if (!fonts_initalized) return FontStoreError.FontStoreNotInitialized;
        return fonts[@intFromEnum(self)];
    }

    ///Loads the font files, and parses them, allowing you to call the `font` function on a enum field and get a BDF in return.
    pub fn init(allocator: std.mem.Allocator) !void {
        if (fonts_initalized) return FontStoreError.FontStoreAlreadyInitialized;
        const font_file_names = @typeInfo(FontStore).@"enum".fields;

        inline for (font_file_names, 0..) |font_file_name, i| {
            const ff = try loadFontFromFile(allocator, font_file_name.name[4..]);
            errdefer ff.deinit(allocator);
            fonts[i] = ff;
        }
        fonts_initalized = true;
    }

    ///Calls `deinit` on all the loaded BDF fonts.
    pub fn deinit(allocator: std.mem.Allocator) void {
        for (0..fonts.len) |i| {
            fonts[i].deinit(allocator);
        }
        fonts_initalized = false;
    }

    ///Attempts to read the contents of a .bdf file located at `./assets/fonts/` and parse a BDF from the text in the file.
    fn loadFontFromFile(allocator: std.mem.Allocator, font_name: []const u8) !BDF {
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();

        const file_name = try std.fmt.allocPrint(arena.allocator(), "./assets/fonts/{s}.bdf", .{font_name});
        const font_file = try std.fs.cwd().readFileAlloc(arena.allocator(), file_name, 1000000);
        return try BDF.parseBDF(allocator, font_file);
    }
};

test "loadFontFromFile" {
    var file_font = try FontStore.loadFontFromFile(std.testing.allocator, "5x8");
    defer file_font.deinit(std.testing.allocator);

    try std.testing.expect(file_font.width == 5);
    try std.testing.expect(file_font.height == 8);
    try std.testing.expect(file_font.default_char == 0);
}

test "font-store-full" {
    try FontStore.init(std.testing.allocator);
    defer FontStore.deinit(std.testing.allocator);

    const font1 = try FontStore.Font5x8.font();
    try std.testing.expect(font1.width == 5);
    try std.testing.expect(font1.height == 8);

    const font2 = try FontStore.Font5x8_2.font();
    try std.testing.expect(font2.width == 5);
    try std.testing.expect(font2.height == 8);

    const font3 = try FontStore.Font7x13.font();
    try std.testing.expect(font3.width == 7);
    try std.testing.expect(font3.height == 13);

    const font4 = try FontStore.Font12x24.font();
    try std.testing.expect(font4.width == 12);
    try std.testing.expect(font4.height == 24);
}
