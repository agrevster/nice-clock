const std = @import("std");
const testing = std.testing;
const common = @import("../common.zig");
const Color = common.Color;

///A PPM Image
pub const PPM = struct {
    width: u8,
    height: u8,
    pixles: []Color,

    pub const Error = error{ InvalidFileType, FailedToParseHeader, UnsuportedMaxColor };

    ///Parses a PPM image file into a `PPM` struct.
    pub fn parsePPM(allocator: std.mem.Allocator, input: []const u8) !PPM {
        var lines = std.mem.tokenizeSequence(u8, input, "\n");

        var width: ?u8 = null;
        var height: ?u8 = null;
        var max_color_value: ?u16 = null;

        var pixles: []Color = undefined;

        //Check to see if the magic numbers match
        if (!std.mem.eql(u8, lines.next().?, "P6")) return Error.InvalidFileType;

        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "#")) {
                continue; // Ignore comments
            } else if (std.ascii.isDigit(line[0]) and (width == null and height == null)) {
                var width_x_height = std.mem.tokenizeSequence(u8, line, " ");
                width = try std.fmt.parseInt(u8, width_x_height.next().?, 10);
                height = try std.fmt.parseInt(u8, width_x_height.next().?, 10);
            } else if (std.ascii.isDigit(line[0]) and max_color_value == null) {
                max_color_value = try std.fmt.parseInt(u16, line, 10);
                break;
            }
        }

        if (width == null or height == null or max_color_value == null) return Error.FailedToParseHeader;
        if (max_color_value.? > 255) return Error.UnsuportedMaxColor;

        const width_u16: u16 = @intCast(width.?);
        const height_u16: u16 = @intCast(height.?);

        pixles = try allocator.alloc(Color, width_u16 * height_u16);
        errdefer allocator.free(pixles);

        //Loop through the raster and convert the u8s to RGB values.
        var pixle_iterator = std.mem.window(u8, lines.next().?, 3, 3);

        const pixle_count: u16 = width.? * height.?;

        for (0..(pixle_count)) |i| {
            const pixle = pixle_iterator.next().?;
            pixles[i] = Color{ .r = pixle[0], .g = pixle[1], .b = pixle[2] };
        }

        return PPM{
            .width = width.?,
            .height = height.?,
            .pixles = pixles,
        };
    }

    ///Calls `deinit` on all loaded pixels.
    pub fn deinit(self: *PPM, allocator: std.mem.Allocator) void {
        allocator.free(self.pixles);
    }
};

test {
    const image_file = try std.fs.cwd().readFileAlloc(testing.allocator, "./assets/images/test.ppm", 1000000);
    var ppm = try PPM.parsePPM(testing.allocator, image_file);
    defer {
        ppm.deinit(testing.allocator);
        testing.allocator.free(image_file);
    }

    try testing.expect(ppm.width == 5);
    try testing.expect(ppm.height == 8);

    for (0..ppm.height) |y| {
        for (0..ppm.width) |x| {
            const pixel = ppm.pixles[y * ppm.width + x];
            if (pixel.elq(Color{ .r = 255, .g = 0, .b = 0 })) {
                std.debug.print("G", .{});
            } else if (pixel.elq(Color{ .r = 0, .g = 255, .b = 0 })) {
                std.debug.print("R", .{});
            } else {
                std.debug.print(" ", .{});
            }
        }
        std.debug.print("\n", .{});
    }
}
