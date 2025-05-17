const std = @import("std");
const common = @import("../common.zig");

const time = std.time;
const math = std.math;
const Connector = common.Connector;
const Color = common.Color;

const logger = std.log.scoped(.Components);

const OverflowError = error{Overflow};

pub const ComponentError = error{ TileOutOfBounds, TimerUnsupported, InvalidArgument };

pub const ComponentPos = struct {
    x: u8,
    y: u8,
};

pub const Component = struct {
    ctx: *const anyopaque,
    draw: *const fn (ctx: *const anyopaque, clock: *Connector) ComponentError!void,
};

pub const RootComponent = struct {
    components: []const Component,

    pub fn render(self: *const RootComponent, clock: *Connector, fps: u8, time_limit_s: u64) ComponentError!void {
        const u64_fps: u64 = @intCast(fps);

        var timer = try std.time.Timer.start();
        var frame: u32 = 0;

        timer.reset();
        while (true) {
            if ((timer.read() / time.ns_per_s) > time_limit_s) break;

            clock.interface.clearScreen(clock.interface.ctx);

            for (self.*.components) |component| {
                try component.draw(component.ctx, clock);
            }

            frame += 1;
            clock.interface.updateScreen(clock.interface.ctx);
            std.time.sleep(time.ns_per_s / u64_fps);
        }
    }
};

pub const TileComponent = struct {
    pos: ComponentPos,
    color: Color,

    pub fn component(self: *const TileComponent) Component {
        return Component{ .ctx = self, .draw = &draw };
    }

    fn draw(ctx: *const anyopaque, clock: *Connector) ComponentError!void {
        const self: *const TileComponent = @ptrCast(@alignCast(ctx));
        try clock.interface.setTile(clock.interface.ctx, self.*.pos.y, self.*.pos.x, self.*.color);
    }
};

pub const BoxComponent = struct {
    pos: ComponentPos,
    width: u8,
    height: u8,
    fill_inside: bool,
    color: Color,

    pub fn component(self: *const BoxComponent) Component {
        return Component{ .ctx = self, .draw = &draw };
    }

    fn draw(ctx: *const anyopaque, clock: *Connector) ComponentError!void {
        const self: *const BoxComponent = @ptrCast(@alignCast(ctx));
        for (self.pos.y..(self.pos.y + self.height)) |y_pos| {
            if (y_pos > 31) continue;

            for (self.pos.x..(self.pos.x + self.width)) |x_pos| {
                if (x_pos > 63) continue;
                const x_pos_u8: u8 = @intCast(x_pos);
                const y_pos_u8: u8 = @intCast(y_pos);
                if (!self.fill_inside) {
                    if (y_pos == self.pos.y or y_pos == self.pos.y + self.height - 1 or x_pos == self.pos.x or x_pos == self.pos.x + self.width - 1) {
                        try clock.interface.setTile(clock.interface.ctx, y_pos_u8, x_pos_u8, self.color);
                    }
                } else try clock.interface.setTile(clock.interface.ctx, y_pos_u8, x_pos_u8, self.color);
            }
        }
    }
};

pub const CircleComponent = struct {
    pos: ComponentPos,
    radius: u8,
    outline_thickness: u8,
    color: Color,

    pub fn component(self: *const CircleComponent) Component {
        return Component{ .ctx = self, .draw = &draw };
    }

    fn setTileIfValid(clock: *Connector, y: OverflowError!u8, x: OverflowError!u8, color: Color) void {
        if (y) |y_val| {
            if (x) |x_val| {
                if (y_val < 32 and x_val < 64) clock.interface.setTile(clock.*.interface.ctx, y_val, x_val, color) catch unreachable;
            } else |_| {}
        } else |_| {}
    }

    fn draw(ctx: *const anyopaque, clock: *Connector) ComponentError!void {
        const self: *const CircleComponent = @ptrCast(@alignCast(ctx));

        if (self.radius <= 0) {
            logger.err("Radius value: {} for circle!", .{self.radius});
            return ComponentError.InvalidArgument;
        }

        if (self.outline_thickness <= 0) {
            logger.err("Outline thickness value: {} for circle!", .{self.outline_thickness});
            return ComponentError.InvalidArgument;
        }

        const center_y_f32: f32 = @floatFromInt(self.pos.y);
        const center_x_f32: f32 = @floatFromInt(self.pos.x);
        const radius_f32: f32 = @floatFromInt(self.radius);
        const outline_thickness_f32: f32 = @floatFromInt(self.outline_thickness);

        for (0..64) |x_pos| {
            for (0..32) |y_pos| {
                const y_pos_f32: f32 = @floatFromInt(y_pos);
                const x_pos_f32: f32 = @floatFromInt(x_pos);

                const distance = math.sqrt(std.math.pow(f32, (y_pos_f32 - center_y_f32), 2) + std.math.pow(f32, (x_pos_f32 - center_x_f32), 2));

                if (distance >= (radius_f32 - outline_thickness_f32) and distance < radius_f32) {
                    try clock.interface.setTile(clock.interface.ctx, @intCast(y_pos), @intCast(x_pos), self.color);
                }
            }
        }
    }
};

pub const CharComponent = struct {
    pos: ComponentPos,
    font: *common.BDF,
    text: u8,
    color: Color,

    pub fn component(self: *const TileComponent) Component {
        return Component{ .ctx = self, .draw = &draw };
    }

    fn draw(ctx: *const anyopaque, clock: *Connector) ComponentError!void {
        const self: *const CharComponent = @ptrCast(@alignCast(ctx));

        const glyph = self.font.glyphs.get(self.char) orelse self.font.glyphs.get(self.font.default_char).?;
        const bytes_per_row = (self.font.width + 7) / 8;

        for (0..self.font.height) |row| {
            const row_start = row * bytes_per_row;
            const row_end = row_start + bytes_per_row;
            const row_bytes = glyph[row_start..row_end];

            var tile_index: u8 = 0;
            for (row_bytes) |byte| {
                for (0..8) |bit| {
                    if (tile_index >= self.font.width) break;
                    const bit_u3: u3 = @intCast(bit);
                    if ((byte & (@as(u8, 0x80) >> bit_u3)) != 0) {
                        clock.interface.setTile(clock, row + self.pos.y, tile_index + self.pos.x, self.color);
                    }
                    tile_index += 1;
                }
            }
        }
    }
};
