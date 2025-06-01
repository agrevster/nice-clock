const std = @import("std");

/// Used to represent RGB colors
pub const ClockColor = struct {
    r: u8,
    g: u8,
    b: u8,

    pub fn format(
        self: ClockColor,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        _ = fmt;
        try writer.print("Color(r={d},g={d},b={d}", .{ self.r, self.g, self.b });
        try writer.writeAll(")");
    }

    pub fn elq(self: ClockColor, comparison: ClockColor) bool {
        return self.r == comparison.r and self.g == comparison.g and self.b == comparison.b;
    }
};
