const std = @import("std");

/// Used to represent RGB colors
pub const ClockColor = struct {
    r: u8,
    g: u8,
    b: u8,

    pub fn format(self: ClockColor, writer: *std.io.Writer) std.io.Writer.Error!void {
        try writer.print("Color(r={d},g={d},b={d}", .{ self.r, self.g, self.b });
        try writer.writeAll(")");
    }

    pub fn elq(self: ClockColor, comparison: ClockColor) bool {
        return self.r == comparison.r and self.g == comparison.g and self.b == comparison.b;
    }
};

test "test new writer" {
    const test_color = ClockColor{ .r = 50, .g = 32, .b = 1 };
    std.debug.print("{f}", .{test_color});
}
