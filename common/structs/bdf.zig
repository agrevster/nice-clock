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

    ///Determines the position of a bit, used for rendering glyphs.
    pub fn bit_at(bits: u8, pos: u3) bool {
        return 1 == (bits >> pos);
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
                const byte = try parseInt(u8, trimmed, 16);
                try bitmap.append(byte);
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
    return error.SkipZigTest;
    // const font_input =
    //     \\STARTFONT 2.1
    //     \\COMMENT $Id: 5x8.bdf,v 1.32 2006-01-05 20:03:17+00 mgk25 Rel $
    //     \\COMMENT Send bug reports to Markus Kuhn <http://www.cl.cam.ac.uk/~mgk25/>
    //     \\FONT -Misc-Fixed-Medium-R-Normal--8-80-75-75-C-50-ISO10646-1
    //     \\SIZE 11 75 75
    //     \\FONTBOUNDINGBOX 5 8 0 -1
    //     \\STARTPROPERTIES 22
    //     \\FONTNAME_REGISTRY ""
    //     \\FOUNDRY "Misc"
    //     \\FAMILY_NAME "Fixed"
    //     \\WEIGHT_NAME "Medium"
    //     \\SLANT "R"
    //     \\SETWIDTH_NAME "Normal"
    //     \\ADD_STYLE_NAME ""
    //     \\PIXEL_SIZE 8
    //     \\POINT_SIZE 80
    //     \\RESOLUTION_X 75
    //     \\RESOLUTION_Y 75
    //     \\SPACING "C"
    //     \\AVERAGE_WIDTH 50
    //     \\CHARSET_REGISTRY "ISO10646"
    //     \\CHARSET_ENCODING "1"
    //     \\FONT_DESCENT 1
    //     \\FONT_ASCENT 7
    //     \\COPYRIGHT "Public domain font.  Share and enjoy."
    //     \\DEFAULT_CHAR 0
    //     \\_XMBDFED_INFO "Edited with xmbdfed 4.5."
    //     \\CAP_HEIGHT 6
    //     \\X_HEIGHT 4
    //     \\ENDPROPERTIES
    //     \\CHARS 1426
    //     \\STARTCHAR char0
    //     \\ENCODING 0
    //     \\SWIDTH 436 0
    //     \\DWIDTH 5 0
    //     \\BBX 5 8 0 -1
    //     \\BITMAP
    //     \\00
    //     \\A0
    //     \\10
    //     \\80
    //     \\10
    //     \\80
    //     \\50
    //     \\00
    //     \\ENDCHAR
    //     \\STARTCHAR exclam
    //     \\ENCODING 33
    //     \\SWIDTH 436 0
    //     \\DWIDTH 5 0
    //     \\BBX 5 8 0 -1
    //     \\BITMAP
    //     \\00
    //     \\20
    //     \\20
    //     \\20
    //     \\20
    //     \\00
    //     \\20
    //     \\00
    //     \\ENDCHAR
    // ;
    // var font = try BDF.parseBDF(std.testing.allocator, font_input);
    // defer font.deinit(std.testing.allocator);
    // std.debug.print("FONT WIDTH x HEIGHT: {d} x {d}\n", .{ font.width, font.height });
    // std.debug.print("DEFAULT_CHAR: {b}\n", .{font.default_char});
    // std.debug.print("Glyphs Capacity: {d}\n", .{font.glyphs.capacity()});
    //
    // // const glyph = font.glyphs.get('!').?;
    // //
    // // for (0..font.height) |y| {
    // //     std.debug.print("\n{b}", .{glyph[y]});
    // //
    // // }
}

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
