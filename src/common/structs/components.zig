const std = @import("std");
const common = @import("../common.zig");

const time = std.time;
const math = std.math;
const Clock = common.Clock;
const Color = common.Color;

const logger = std.log.scoped(.components);

const OverflowError = error{Overflow};

pub const ComponentError = error{ TileOutOfBounds, TimerUnsupported, InvalidArgument, AllocationError } || common.font.FontStore.FontStoreError || common.image.ImageStore.Error;

/// Used to specify the position of a component on the clock's screen.
pub const ComponentPos = struct {
    x: u8,
    y: u8,
};

///Components are the building blocks of clock modules.
///Each component struct should have a method *(methods have *@This)* called `component` that returns a `Component`
///
/// `ctx` should point to a component struct's `@This`
/// `draw` should point to a function used to draw the component.
///
/// If you need to a access `*@This` in draw use this block
///
/// ```zig
/// const self: *const @This = @ptrCast(@alignCast(ctx));
/// ````
pub const Component = struct {
    ctx: *const anyopaque,
    draw: *const fn (ctx: *const anyopaque, clock: *Clock) ComponentError!void,
};

///This struct represents a `Component` with an animation. Duration is how many ticks the animation lasts while speed is used to specify how long in between ticks.
pub const AnimationComponent = struct {
    component: Component,
    update_animation: *const fn (clock: *Clock, frame_number: u32) void,
    duration: u32,
    loop: bool,
    speed: i16,

    pub fn timed_animation(self: *const AnimationComponent) TimedAnimation {
        return TimedAnimation{
            .base = self.*,
            .internal_frame = 0,
        };
    }
};

///An internal wrapper used to ensure that animations update only when they should.
pub const TimedAnimation = struct {
    base: AnimationComponent,
    internal_frame: u32,

    pub fn update_animation(self: *TimedAnimation, clock: *Clock, global_frame: u32) void {
        // Stop updating if we're not looping and have reached the end
        if (self.base.duration > 0 and !self.base.loop and self.internal_frame >= self.base.duration) {
            return;
        }

        // Advance animation only every `speed` frames
        const u32_speed: u32 = @intCast(self.base.speed);
        if (self.base.speed > 0 and global_frame % u32_speed == 0) {
            self.base.update_animation(clock, self.internal_frame);
            self.internal_frame += 1;

            if (self.base.loop and self.internal_frame >= self.base.duration) {
                self.internal_frame = 0;
            }
        }
    }
};

pub const AnyComponent = union(enum) { animated: AnimationComponent, normal: Component };

///Each module has a root component which is responsible for drawing every component
pub const RootComponent = struct {
    components: []const AnyComponent,

    ///Returns the speed of the fastest child's animation updates or `null` if there are no animated components. *or animated components with 0 as speed*
    fn getFastestAnimationSpeed(self: *const RootComponent) ?i16 {
        var max: i16 = 0;
        for (self.components) |any_component| {
            if (any_component == AnyComponent.animated) {
                const animation = any_component.animated;
                if (animation.speed > max) max = animation.speed;
            }
        }
        return if (max == 0) null else max;
    }

    ///This function draws each component in order. It redraws each component `fps` time per second and stop drawing after `time_limit_s` seconds.
    pub fn render(self: *const RootComponent, clock: *Clock, fps: u8, time_limit_s: u64) ComponentError!void {
        const u64_fps: u64 = @intCast(fps);
        const sleep_time_ns = time.ns_per_s / u64_fps;
        const fastest_animation: ?i16 = self.getFastestAnimationSpeed();

        // Preprocess animated components
        var timed_animations = clock.allocator.alloc(TimedAnimation, self.components.len) catch return ComponentError.AllocationError;
        defer clock.allocator.free(timed_animations);
        var timed_count: usize = 0;

        for (self.components) |comp| {
            if (comp == AnyComponent.animated) {
                timed_animations[timed_count] = comp.animated.timed_animation();
                timed_count += 1;
            }
        }

        // Sort animations by speed so that they redraw in the correct order.
        std.mem.sort(TimedAnimation, timed_animations, {}, struct {
            fn less_than(_: void, a: TimedAnimation, b: TimedAnimation) bool {
                return b.base.speed < a.base.speed;
            }
        }.less_than);

        var timer = try std.time.Timer.start();
        var frame: u32 = 0;

        timer.reset();

        while (true) {
            if ((timer.read() / time.ns_per_s) > time_limit_s) break;
            clock.interface.clearScreen(clock.interface.ctx);

            // Draw normal components
            for (self.components) |comp| {
                if (comp == AnyComponent.normal) {
                    try comp.normal.draw(comp.normal.ctx, clock);
                }
            }

            // Update + draw animated components
            for (timed_animations[0..timed_count]) |*timed| {
                timed.update_animation(clock, frame);
                if (fastest_animation != null and fastest_animation == timed.base.speed) clock.interface.clearScreen(clock.interface.ctx);
                try timed.base.component.draw(timed.base.component.ctx, clock);
            }

            frame += 1;
            clock.interface.updateScreen(clock.interface.ctx);
            std.time.sleep(sleep_time_ns);
        }
    }
};

///Used to represent single tiles on the screen, at position `pos` and of color `color`.
pub const TileComponent = struct {
    pos: ComponentPos,
    color: Color,

    pub fn component(self: *const TileComponent) Component {
        return Component{ .ctx = self, .draw = &draw };
    }

    fn draw(ctx: *const anyopaque, clock: *Clock) ComponentError!void {
        const self: *const TileComponent = @ptrCast(@alignCast(ctx));
        try clock.interface.setTile(clock.interface.ctx, self.*.pos.y, self.*.pos.x, self.*.color);
    }
};

///Used to represent a rectangle on the screen of a given width and height.
pub const BoxComponent = struct {
    pos: ComponentPos,
    width: u8,
    height: u8,
    fill_inside: bool,
    color: Color,

    pub fn component(self: *const BoxComponent) Component {
        return Component{ .ctx = self, .draw = &draw };
    }

    fn draw(ctx: *const anyopaque, clock: *Clock) ComponentError!void {
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

///Used to represent a circle on the screen.
///*The outline thickness can be used to fill in the circle.*
pub const CircleComponent = struct {
    pos: ComponentPos,
    radius: u8,
    outline_thickness: u8,
    color: Color,

    pub fn component(self: *const CircleComponent) Component {
        return Component{ .ctx = self, .draw = &draw };
    }

    fn setTileIfValid(clock: *Clock, y: OverflowError!u8, x: OverflowError!u8, color: Color) void {
        if (y) |y_val| {
            if (x) |x_val| {
                if (y_val < 32 and x_val < 64) clock.interface.setTile(clock.*.interface.ctx, y_val, x_val, color) catch unreachable;
            } else |_| {}
        } else |_| {}
    }

    fn draw(ctx: *const anyopaque, clock: *Clock) ComponentError!void {
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

fn drawChar(clock: *Clock, y_pos: u8, x_pos: u8, font: common.font.BDF, char: u8, color: Color) ComponentError!void {
    const glyph = font.glyphs.get(char) orelse font.glyphs.get(font.default_char).?;
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
                    const row_u8: u8 = @intCast(row);
                    try clock.interface.setTile(clock.interface.ctx, row_u8 + y_pos, tile_index + x_pos, color);
                }
                tile_index += 1;
            }
        }
    }
}

///Used to draw a single glyph from the given `font` on the screen.
pub const CharComponent = struct {
    pos: ComponentPos,
    font: common.font.FontStore,
    char: u8,
    color: Color,

    pub fn component(self: *const CharComponent) Component {
        return Component{ .ctx = self, .draw = &draw };
    }

    fn draw(ctx: *const anyopaque, clock: *Clock) ComponentError!void {
        const self: *const CharComponent = @ptrCast(@alignCast(ctx));
        try drawChar(clock, self.pos.y, self.pos.x, try self.font.font(), self.char, self.color);
    }
};

///Used to draw text from a given `font` on the screen.
pub const TextComponent = struct {
    pos: ComponentPos,
    font: common.font.FontStore,
    text: []const u8,
    color: Color,

    pub fn component(self: *const TextComponent) Component {
        return Component{ .ctx = self, .draw = &draw };
    }

    fn draw(ctx: *const anyopaque, clock: *Clock) ComponentError!void {
        const self: *const TextComponent = @ptrCast(@alignCast(ctx));

        var char_x = self.pos.x;
        const font = try self.font.font();

        for (self.text) |char| {
            try drawChar(clock, self.pos.y, char_x, font, char, self.color);
            char_x += font.width;
        }
    }
};

///Used to draw text from a given `font` on the screen.
///When the text reaches the edge of the screen or the char `\n` is found it gets wrapped down to the next line.
pub const WrappedTextComponent = struct {
    pos: ComponentPos,
    font: common.font.FontStore,
    text: []const u8,
    color: Color,
    ///Used to specify how many additional tiles are between each line. Negative entries are acceptable.
    line_spacing: i8 = 0,

    pub fn component(self: *const WrappedTextComponent) Component {
        return Component{ .ctx = self, .draw = &draw };
    }

    ///Allows for addition of negative i8 `spacing` to u8 `initial`.
    ///*If the number is negative returns `0`*
    //This is pretty clumsy but it does the job, and fingers crossed no one will overflow because the screen is only 64x32
    fn process_spacing(initial: u8, spacing: i8) u8 {
        var x = initial;

        if (spacing >= 0) {
            x += @as(u8, @intCast(spacing));
        } else {
            x -= @as(u8, @intCast(@abs(spacing)));
        }

        return x;
    }

    fn draw(ctx: *const anyopaque, clock: *Clock) ComponentError!void {
        const self: *const WrappedTextComponent = @ptrCast(@alignCast(ctx));

        var y = self.pos.y;
        var x = self.pos.x;
        const font = try self.font.font();

        for (self.text) |char| {
            if (x + font.width >= 64) {
                x = self.pos.x;

                y += process_spacing(font.height, self.line_spacing);

                if (y > 31 - font.height) break; //We don't want to draw text off the screen
            }
            try drawChar(clock, y, x, font, char, self.color);
            x += font.width;
        }
    }
};

///Used to draw an image onto the screen.
pub const ImageComponent = struct {
    pos: ComponentPos,
    image_name: []const u8,

    pub fn component(self: *const ImageComponent) Component {
        return Component{ .ctx = self, .draw = &draw };
    }

    const black = common.Color{ .r = 0, .g = 0, .b = 0 };

    fn draw(ctx: *const anyopaque, clock: *Clock) ComponentError!void {
        const self: *const ImageComponent = @ptrCast(@alignCast(ctx));

        const image = try clock.image_store.get_image(self.image_name);

        for (0..image.height) |y| {
            const y_u8: u8 = @intCast(y);
            for (0..image.width) |x| {
                const x_u8: u8 = @intCast(x);
                const pixel = image.pixles[y * image.width + x];
                if (!pixel.elq(black)) try clock.interface.setTile(clock.interface.ctx, y_u8 + self.pos.y, x_u8 + self.pos.x, pixel);
            }
        }
    }
};
