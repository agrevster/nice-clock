const std = @import("std");
const common = @import("../common.zig");

const time = std.time;
const math = std.math;
const Clock = common.Clock;
const Color = common.Color;
const LuauComponentConstructorError = common.luau.import_components.LuauComponentConstructorError;
const LuauArg = common.luau.import_components.LuauArg;

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
    ctx: *anyopaque,
    draw: *const fn (ctx: *anyopaque, clock: *Clock) ComponentError!void,
};

///This struct represents a `Component` with an animation. Duration is how many ticks the animation lasts while speed is used to specify how long in between ticks.
pub const AnimationComponent = struct {
    component: Component,
    update_animation: *const fn (ctx: *anyopaque, clock: *Clock, frame_number: u32) void,
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
            self.base.update_animation(self.base.component.ctx, clock, self.internal_frame);
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

            // Update + draw animated components
            for (timed_animations[0..timed_count]) |*timed| {
                timed.update_animation(clock, frame);
                if (fastest_animation != null and fastest_animation == timed.base.speed) clock.interface.clearScreen(clock.interface.ctx);
                try timed.base.component.draw(timed.base.component.ctx, clock);
            }

            // Draw normal components
            for (self.components) |comp| {
                if (comp == AnyComponent.normal) {
                    try comp.normal.draw(comp.normal.ctx, clock);
                }
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

    pub fn component(self: *TileComponent) Component {
        return Component{ .ctx = self, .draw = &draw };
    }

    pub fn from_luau(args: []LuauArg, allocator: std.mem.Allocator) LuauComponentConstructorError!*AnyComponent {
        const pos_arg = try LuauArg.getPosOrError(args, 0);
        const color_arg = try LuauArg.getColorOrError(args, 1);

        const color = allocator.create(Color) catch return LuauComponentConstructorError.MemoryError;
        const pos = allocator.create(ComponentPos) catch return LuauComponentConstructorError.MemoryError;
        const comp = allocator.create(TileComponent) catch return LuauComponentConstructorError.MemoryError;
        const ret = allocator.create(AnyComponent) catch return LuauComponentConstructorError.MemoryError;

        color.* = Color{ .r = color_arg.r, .g = color_arg.g, .b = color_arg.b };
        pos.* = ComponentPos{ .x = pos_arg.x, .y = pos_arg.y };
        comp.* = TileComponent{ .pos = pos.*, .color = color.* };
        ret.* = AnyComponent{ .normal = comp.*.component() };
        return ret;
    }

    fn draw(ctx: *anyopaque, clock: *Clock) ComponentError!void {
        const self: *TileComponent = @ptrCast(@alignCast(ctx));
        try clock.interface.setTile(clock.interface.ctx, self.pos.y, self.pos.x, self.color);
    }
};

///Used to represent a rectangle on the screen of a given width and height.
pub const BoxComponent = struct {
    pos: ComponentPos,
    width: u8,
    height: u8,
    fill_inside: bool,
    color: Color,

    pub fn component(self: *BoxComponent) Component {
        return Component{ .ctx = self, .draw = &draw };
    }

    pub fn from_luau(args: []LuauArg, allocator: std.mem.Allocator) LuauComponentConstructorError!*AnyComponent {
        const pos_arg = try LuauArg.getPosOrError(args, 0);
        const width_arg = try LuauArg.getU8IntOrError(args, 1);
        const height_arg = try LuauArg.getU8IntOrError(args, 2);
        const fill_inside_arg = try LuauArg.getBoolOrError(args, 3);
        const color_arg = try LuauArg.getColorOrError(args, 4);

        const pos = allocator.create(ComponentPos) catch return LuauComponentConstructorError.MemoryError;
        const width = allocator.create(u8) catch return LuauComponentConstructorError.MemoryError;
        const height = allocator.create(u8) catch return LuauComponentConstructorError.MemoryError;
        const fill_inside = allocator.create(bool) catch return LuauComponentConstructorError.MemoryError;
        const color = allocator.create(Color) catch return LuauComponentConstructorError.MemoryError;
        const comp = allocator.create(BoxComponent) catch return LuauComponentConstructorError.MemoryError;
        const ret = allocator.create(AnyComponent) catch return LuauComponentConstructorError.MemoryError;

        pos.* = ComponentPos{ .x = pos_arg.x, .y = pos_arg.y };
        width.* = width_arg;
        height.* = height_arg;
        fill_inside.* = fill_inside_arg;
        color.* = Color{ .r = color_arg.r, .g = color_arg.g, .b = color_arg.b };
        comp.* = BoxComponent{ .pos = pos.*, .color = color.*, .width = width.*, .height = height.*, .fill_inside = fill_inside.* };
        ret.* = AnyComponent{ .normal = comp.*.component() };
        return ret;
    }

    fn draw(ctx: *anyopaque, clock: *Clock) ComponentError!void {
        const self: *BoxComponent = @ptrCast(@alignCast(ctx));
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

    pub fn component(self: *CircleComponent) Component {
        return Component{ .ctx = self, .draw = &draw };
    }

    pub fn from_luau(args: []LuauArg, allocator: std.mem.Allocator) LuauComponentConstructorError!*AnyComponent {
        const pos_arg = try LuauArg.getPosOrError(args, 0);
        const radius_arg = try LuauArg.getU8IntOrError(args, 1);
        const outline_thickness_arg = try LuauArg.getU8IntOrError(args, 2);
        const color_arg = try LuauArg.getColorOrError(args, 3);

        const pos = allocator.create(ComponentPos) catch return LuauComponentConstructorError.MemoryError;
        const radius = allocator.create(u8) catch return LuauComponentConstructorError.MemoryError;
        const outline_thickness = allocator.create(u8) catch return LuauComponentConstructorError.MemoryError;
        const color = allocator.create(Color) catch return LuauComponentConstructorError.MemoryError;
        const comp = allocator.create(CircleComponent) catch return LuauComponentConstructorError.MemoryError;
        const ret = allocator.create(AnyComponent) catch return LuauComponentConstructorError.MemoryError;

        pos.* = ComponentPos{ .x = pos_arg.x, .y = pos_arg.y };
        radius.* = radius_arg;
        outline_thickness.* = outline_thickness_arg;
        color.* = Color{ .r = color_arg.r, .g = color_arg.g, .b = color_arg.b };
        comp.* = CircleComponent{ .pos = pos.*, .color = color.*, .radius = radius.*, .outline_thickness = outline_thickness.* };
        ret.* = AnyComponent{ .normal = comp.*.component() };
        return ret;
    }

    fn setTileIfValid(clock: *Clock, y: OverflowError!u8, x: OverflowError!u8, color: Color) void {
        if (y) |y_val| {
            if (x) |x_val| {
                if (y_val < 32 and x_val < 64) clock.interface.setTile(clock.*.interface.ctx, y_val, x_val, color) catch unreachable;
            } else |_| {}
        } else |_| {}
    }

    fn draw(ctx: *anyopaque, clock: *Clock) ComponentError!void {
        const self: *CircleComponent = @ptrCast(@alignCast(ctx));

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

fn draw_char(clock: *Clock, y_pos: u8, x_pos: u8, font: common.font.BDF, char: u8, color: Color) ComponentError!void {
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

    pub fn component(self: *CharComponent) Component {
        return Component{ .ctx = self, .draw = &draw };
    }

    pub fn from_luau(args: []LuauArg, allocator: std.mem.Allocator) LuauComponentConstructorError!*AnyComponent {
        const pos_arg = try LuauArg.getPosOrError(args, 0);
        const font_arg = try LuauArg.getFontOrError(args, 1);
        const char_arg = try LuauArg.getCharOrError(args, 2);
        const color_arg = try LuauArg.getColorOrError(args, 3);

        const pos = allocator.create(ComponentPos) catch return LuauComponentConstructorError.MemoryError;
        const font = allocator.create(common.font.FontStore) catch return LuauComponentConstructorError.MemoryError;
        const char = allocator.create(u8) catch return LuauComponentConstructorError.MemoryError;
        const color = allocator.create(Color) catch return LuauComponentConstructorError.MemoryError;
        const comp = allocator.create(CharComponent) catch return LuauComponentConstructorError.MemoryError;
        const ret = allocator.create(AnyComponent) catch return LuauComponentConstructorError.MemoryError;

        pos.* = ComponentPos{ .x = pos_arg.x, .y = pos_arg.y };
        color.* = Color{ .r = color_arg.r, .g = color_arg.g, .b = color_arg.b };
        font.* = font_arg;
        char.* = char_arg;
        comp.* = CharComponent{ .pos = pos.*, .color = color.*, .font = font.*, .char = char.* };
        ret.* = AnyComponent{ .normal = comp.*.component() };
        return ret;
    }

    fn draw(ctx: *anyopaque, clock: *Clock) ComponentError!void {
        const self: *CharComponent = @ptrCast(@alignCast(ctx));
        try draw_char(clock, self.pos.y, self.pos.x, try self.font.font(), self.char, self.color);
    }
};

///Used to draw text from a given `font` on the screen.
pub const TextComponent = struct {
    pos: ComponentPos,
    font: common.font.FontStore,
    text: []const u8,
    color: Color,

    pub fn component(self: *TextComponent) Component {
        return Component{ .ctx = self, .draw = &draw };
    }

    pub fn from_luau(args: []LuauArg, allocator: std.mem.Allocator) LuauComponentConstructorError!*AnyComponent {
        const pos_arg = try LuauArg.getPosOrError(args, 0);
        const font_arg = try LuauArg.getFontOrError(args, 1);
        const text_arg = try LuauArg.getStringOrError(args, 2);
        const color_arg = try LuauArg.getColorOrError(args, 3);

        const pos = allocator.create(ComponentPos) catch return LuauComponentConstructorError.MemoryError;
        const font = allocator.create(common.font.FontStore) catch return LuauComponentConstructorError.MemoryError;
        const text = allocator.dupeZ(u8, text_arg) catch return LuauComponentConstructorError.MemoryError;
        const color = allocator.create(Color) catch return LuauComponentConstructorError.MemoryError;
        const comp = allocator.create(TextComponent) catch return LuauComponentConstructorError.MemoryError;
        const ret = allocator.create(AnyComponent) catch return LuauComponentConstructorError.MemoryError;

        std.mem.copyForwards(u8, text, text_arg);

        pos.* = ComponentPos{ .x = pos_arg.x, .y = pos_arg.y };
        color.* = Color{ .r = color_arg.r, .g = color_arg.g, .b = color_arg.b };
        font.* = font_arg;
        comp.* = TextComponent{ .pos = pos.*, .color = color.*, .font = font.*, .text = text };
        ret.* = AnyComponent{ .normal = comp.*.component() };
        return ret;
    }

    fn draw(ctx: *anyopaque, clock: *Clock) ComponentError!void {
        const self: *TextComponent = @ptrCast(@alignCast(ctx));

        var char_x = self.pos.x;
        const font = try self.font.font();

        for (self.text) |char| {
            try draw_char(clock, self.pos.y, char_x, font, char, self.color);
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

    pub fn component(self: *WrappedTextComponent) Component {
        return Component{ .ctx = self, .draw = &draw };
    }

    pub fn from_luau(args: []LuauArg, allocator: std.mem.Allocator) LuauComponentConstructorError!*AnyComponent {
        const pos_arg = try LuauArg.getPosOrError(args, 0);
        const font_arg = try LuauArg.getFontOrError(args, 1);
        const text_arg = try LuauArg.getStringOrError(args, 2);
        const color_arg = try LuauArg.getColorOrError(args, 3);
        const line_spacing_arg = try LuauArg.getI8IntOrError(args, 4);

        const pos = allocator.create(ComponentPos) catch return LuauComponentConstructorError.MemoryError;
        const font = allocator.create(common.font.FontStore) catch return LuauComponentConstructorError.MemoryError;
        const text = allocator.dupeZ(u8, text_arg) catch return LuauComponentConstructorError.MemoryError;
        const color = allocator.create(Color) catch return LuauComponentConstructorError.MemoryError;
        const line_spacing = allocator.create(i8) catch return LuauComponentConstructorError.MemoryError;
        const comp = allocator.create(WrappedTextComponent) catch return LuauComponentConstructorError.MemoryError;
        const ret = allocator.create(AnyComponent) catch return LuauComponentConstructorError.MemoryError;

        std.mem.copyForwards(u8, text, text_arg);

        pos.* = ComponentPos{ .x = pos_arg.x, .y = pos_arg.y };
        color.* = Color{ .r = color_arg.r, .g = color_arg.g, .b = color_arg.b };
        font.* = font_arg;
        line_spacing.* = line_spacing_arg;
        comp.* = WrappedTextComponent{ .pos = pos.*, .color = color.*, .font = font.*, .text = text, .line_spacing = line_spacing.* };
        ret.* = AnyComponent{ .normal = comp.*.component() };
        return ret;
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

    fn draw(ctx: *anyopaque, clock: *Clock) ComponentError!void {
        const self: *WrappedTextComponent = @ptrCast(@alignCast(ctx));

        var y = self.pos.y;
        var x = self.pos.x;
        const font = try self.font.font();

        for (self.text) |char| {
            if (char == '\n') {
                y += process_spacing(font.height, self.line_spacing);
                x = self.pos.x;
                continue;
            }

            if (x + font.width >= 64) {
                x = self.pos.x;

                y += process_spacing(font.height, self.line_spacing);

                if (y > 31 - font.height) break; //We don't want to draw text off the screen
            }
            try draw_char(clock, y, x, font, char, self.color);
            x += font.width;
        }
    }
};

///Used to draw an image onto the screen.
pub const ImageComponent = struct {
    pos: ComponentPos,
    image_name: []const u8,

    pub fn component(self: *ImageComponent) Component {
        return Component{ .ctx = self, .draw = &draw };
    }

    pub fn from_luau(args: []LuauArg, allocator: std.mem.Allocator) LuauComponentConstructorError!*AnyComponent {
        const pos_arg = try LuauArg.getPosOrError(args, 0);
        const image_name_arg = try LuauArg.getStringOrError(args, 1);

        const pos = allocator.create(ComponentPos) catch return LuauComponentConstructorError.MemoryError;
        const image_name = allocator.dupeZ(u8, image_name_arg) catch return LuauComponentConstructorError.MemoryError;
        const comp = allocator.create(ImageComponent) catch return LuauComponentConstructorError.MemoryError;
        const ret = allocator.create(AnyComponent) catch return LuauComponentConstructorError.MemoryError;

        pos.* = ComponentPos{ .x = pos_arg.x, .y = pos_arg.y };
        std.mem.copyForwards(u8, image_name, image_name_arg);
        comp.* = ImageComponent{ .pos = pos.*, .image_name = image_name };
        ret.* = AnyComponent{ .normal = comp.*.component() };
        return ret;
    }

    const black = common.Color{ .r = 0, .g = 0, .b = 0 };

    fn draw(ctx: *anyopaque, clock: *Clock) ComponentError!void {
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

///Used to draw text that scrolls across the screen
///
///Start pos is used to denote where the text starts appearing from
///cutoff_x is the x value where the text disappears.
///text_pos should equal -(start_pos.x) it is used to determine where the text starts out
pub const HorizontalScrollingTextComponent = struct {
    start_pos: ComponentPos,
    font: common.font.FontStore,
    text: []const u8,
    color: Color,
    cutoff_x: u8,
    text_pos: i32 = -64,

    ///WARNING: This is for internal use only. If you want to draw this use animation()
    fn component(self: *HorizontalScrollingTextComponent) Component {
        return Component{ .ctx = self, .draw = &draw };
    }

    pub fn animation(self: *HorizontalScrollingTextComponent, duration: u32, loop: bool, speed: i16) AnimationComponent {
        return AnimationComponent{
            .component = self.component(),
            .duration = duration,
            .loop = loop,
            .speed = speed,
            .update_animation = &update_animation,
        };
    }

    pub fn from_luau(args: []LuauArg, allocator: std.mem.Allocator) LuauComponentConstructorError!*AnyComponent {
        const start_pos_arg = try LuauArg.getPosOrError(args, 0);
        const font_arg = try LuauArg.getFontOrError(args, 1);
        const text_arg = try LuauArg.getStringOrError(args, 2);
        const color_arg = try LuauArg.getColorOrError(args, 3);
        const cutoff_x_arg = try LuauArg.getU8IntOrError(args, 4);
        const text_pos_arg = try LuauArg.getI32IntOrError(args, 5);
        const animation_arg = try LuauArg.getAnimationOrError(args, 6);

        if (start_pos_arg.x < cutoff_x_arg) {
            logger.err("x pos should be greater than cutoff x!", .{});
            return LuauComponentConstructorError.ValidationError;
        }

        const start_pos = allocator.create(ComponentPos) catch return LuauComponentConstructorError.MemoryError;
        const font = allocator.create(common.font.FontStore) catch return LuauComponentConstructorError.MemoryError;
        const text = allocator.dupeZ(u8, text_arg) catch return LuauComponentConstructorError.MemoryError;
        const color = allocator.create(Color) catch return LuauComponentConstructorError.MemoryError;
        const cutoff_x = allocator.create(u8) catch return LuauComponentConstructorError.MemoryError;
        const text_pos = allocator.create(i32) catch return LuauComponentConstructorError.MemoryError;
        const comp = allocator.create(HorizontalScrollingTextComponent) catch return LuauComponentConstructorError.MemoryError;
        const ret = allocator.create(AnyComponent) catch return LuauComponentConstructorError.MemoryError;

        std.mem.copyForwards(u8, text, text_arg);

        start_pos.* = ComponentPos{ .x = start_pos_arg.x, .y = start_pos_arg.y };
        color.* = Color{ .r = color_arg.r, .g = color_arg.g, .b = color_arg.b };
        font.* = font_arg;
        cutoff_x.* = cutoff_x_arg;
        text_pos.* = text_pos_arg;
        comp.* = HorizontalScrollingTextComponent{ .start_pos = start_pos.*, .color = color.*, .font = font.*, .text = text, .text_pos = text_pos.*, .cutoff_x = cutoff_x.* };
        ret.* = AnyComponent{ .animated = comp.*.animation(animation_arg.duration, animation_arg.loop, animation_arg.speed) };
        return ret;
    }

    fn update_animation(ctx: *anyopaque, clock: *Clock, frame_number: u32) void {
        const comp: *HorizontalScrollingTextComponent = @ptrCast(@alignCast(ctx));
        _ = clock;
        _ = frame_number;
        comp.text_pos += 1;
    }

    fn draw_char_column_if_possible(clock: *Clock, y_pos: u8, x_pos: u8, font: common.font.BDF, char: u8, column: u8, color: Color) ComponentError!void {
        if (y_pos > 31 or x_pos > 64) return;
        if (column >= font.width) return;
        const glyph = font.glyphs.get(char) orelse font.glyphs.get(font.default_char).?;
        const bytes_per_row = (font.width + 7) / 8;

        for (0..font.height) |row| {
            const row_start = row * bytes_per_row;
            const row_bytes = glyph[row_start .. row_start + bytes_per_row];

            const row_u8: u8 = @intCast(row);

            if ((row_u8 + y_pos) > 31) break;

            const byte_index = column / 8;

            const bit_u3: u3 = @intCast(column);
            const byte = row_bytes[byte_index];
            if ((byte & (@as(u8, 0x80) >> bit_u3)) != 0) {
                try clock.interface.setTile(clock.interface.ctx, row_u8 + y_pos, x_pos, color);
            }
        }
    }

    fn get_char_and_y(text: []const u8, font: common.font.BDF, text_pixel_x: usize) ?[2]usize {
        const char_index: usize = text_pixel_x / font.width;
        const char_y: usize = text_pixel_x % font.width;
        if (char_index >= text.len or char_y >= font.width) return null;
        return [2]usize{ char_index, char_y };
    }

    fn draw(ctx: *anyopaque, clock: *Clock) ComponentError!void {
        const self: *HorizontalScrollingTextComponent = @ptrCast(@alignCast(ctx));
        const font = try self.font.font();

        const text_pixel_length = self.text.len * font.width;
        const start_pos_i9: i9 = @intCast(self.start_pos.x);

        // Reset the text_pos when the text has all reached the end
        if (self.text_pos >= text_pixel_length) self.text_pos = -start_pos_i9;

        for (self.cutoff_x..self.start_pos.x) |x| {
            const x_i9: i9 = @intCast(x);
            const text_pixel_x = x_i9 + self.text_pos;

            // Used to make sure that we start at the rightmost corner
            if (text_pixel_x < 0 or text_pixel_x >= text_pixel_length) continue;

            const text_pixel_x_usize: usize = @intCast(@max(0, text_pixel_x));

            if (get_char_and_y(self.text, font, text_pixel_x_usize)) |info| {
                const x_u8: u8 = @intCast(x);
                const column: u8 = @truncate(info[1]);
                try draw_char_column_if_possible(clock, self.start_pos.y, x_u8, font, self.text[info[0]], column, self.color);
            }
        }
    }
};

///Used to draw text that scrolls across the screen vertically
pub const VerticalScrollingTextComponent = struct {
    start_pos: ComponentPos,
    width: u8,
    height: u8,
    font: common.font.FontStore,
    text: []const u8,
    color: Color,
    text_pos: i32 = 0,
    starting_text_pos: i32 = 0,
    line_spacing: u8,

    ///WARNING: This is for internal use only. If you want to draw this use animation()
    fn component(self: *VerticalScrollingTextComponent) Component {
        return Component{ .ctx = self, .draw = &draw };
    }

    pub fn animation(self: *VerticalScrollingTextComponent, duration: u32, loop: bool, speed: i16) AnimationComponent {
        return AnimationComponent{
            .component = self.component(),
            .duration = duration,
            .loop = loop,
            .speed = speed,
            .update_animation = &update_animation,
        };
    }

    pub fn from_luau(args: []LuauArg, allocator: std.mem.Allocator) LuauComponentConstructorError!*AnyComponent {
        const start_pos_arg = try LuauArg.getPosOrError(args, 0);
        const width_arg = try LuauArg.getU8IntOrError(args, 1);
        const height_arg = try LuauArg.getU8IntOrError(args, 2);
        const font_arg = try LuauArg.getFontOrError(args, 3);
        const text_arg = try LuauArg.getStringOrError(args, 4);
        const color_arg = try LuauArg.getColorOrError(args, 5);
        const text_pos_arg = try LuauArg.getI32IntOrError(args, 6);
        const line_spacing_arg = try LuauArg.getU8IntOrError(args, 7);
        const animation_arg = try LuauArg.getAnimationOrError(args, 8);

        const start_pos = allocator.create(ComponentPos) catch return LuauComponentConstructorError.MemoryError;
        const width = allocator.create(u8) catch return LuauComponentConstructorError.MemoryError;
        const height = allocator.create(u8) catch return LuauComponentConstructorError.MemoryError;
        const font = allocator.create(common.font.FontStore) catch return LuauComponentConstructorError.MemoryError;
        const text = allocator.dupeZ(u8, text_arg) catch return LuauComponentConstructorError.MemoryError;
        const color = allocator.create(Color) catch return LuauComponentConstructorError.MemoryError;
        const text_pos = allocator.create(i32) catch return LuauComponentConstructorError.MemoryError;
        const line_spacing = allocator.create(u8) catch return LuauComponentConstructorError.MemoryError;
        const comp = allocator.create(VerticalScrollingTextComponent) catch return LuauComponentConstructorError.MemoryError;
        const ret = allocator.create(AnyComponent) catch return LuauComponentConstructorError.MemoryError;

        std.mem.copyForwards(u8, text, text_arg);

        start_pos.* = ComponentPos{ .x = start_pos_arg.x, .y = start_pos_arg.y };
        width.* = width_arg;
        height.* = height_arg;
        font.* = font_arg;
        color.* = Color{ .r = color_arg.r, .g = color_arg.g, .b = color_arg.b };
        text_pos.* = text_pos_arg;
        line_spacing.* = line_spacing_arg;
        comp.* = VerticalScrollingTextComponent{
            .start_pos = start_pos.*,
            .color = color.*,
            .font = font.*,
            .text = text,
            .starting_text_pos = text_pos.*,
            .text_pos = text_pos.*,
            .width = width.*,
            .height = height.*,
            .line_spacing = line_spacing.*,
        };
        ret.* = AnyComponent{ .animated = comp.*.animation(animation_arg.duration, animation_arg.loop, animation_arg.speed) };
        return ret;
    }

    fn update_animation(ctx: *anyopaque, clock: *Clock, frame_number: u32) void {
        const comp: *VerticalScrollingTextComponent = @ptrCast(@alignCast(ctx));
        _ = clock;
        _ = frame_number;
        comp.text_pos += 1;
    }

    fn draw_char_if_possible(clock: *Clock, y_pos: i9, x_pos: i9, font: common.font.BDF, char: u8, color: Color) ComponentError!void {
        if (y_pos < -@as(i9, @intCast(font.height))) return;
        const glyph = font.glyphs.get(char) orelse font.glyphs.get(font.default_char).?;
        const bytes_per_row = (font.width + 7) / 8;

        for (0..font.height) |row| {
            const row_start = row * bytes_per_row;
            const row_end = row_start + bytes_per_row;
            const row_bytes = glyph[row_start..row_end];

            var tile_index: i9 = 0;
            for (row_bytes) |byte| {
                for (0..8) |bit| {
                    const bit_u3: u3 = @intCast(bit);
                    if ((byte & (@as(u8, 0x80) >> bit_u3)) != 0) {
                        const row_i9: i9 = @intCast(row);
                        if ((row_i9 + y_pos) > 31 or (row_i9 + y_pos) < 0 or (tile_index + x_pos) > 63 or (tile_index + x_pos) < 0) break;
                        const x: u8 = @intCast(tile_index + x_pos);
                        const y: u8 = @intCast(row_i9 + y_pos);
                        try clock.interface.setTile(clock.interface.ctx, y, x, color);
                    }
                    tile_index += 1;
                }
            }
        }
    }

    fn draw(ctx: *anyopaque, clock: *Clock) ComponentError!void {
        const self: *VerticalScrollingTextComponent = @ptrCast(@alignCast(ctx));
        const font = try self.font.font();

        var lines_buf: [64]std.BoundedArray(u8, 128) = undefined;
        var lines_count: usize = 0;
        var i: usize = 0;
        while (i < self.text.len and lines_count < lines_buf.len) {
            var line = std.BoundedArray(u8, 128).init(0) catch break;
            var line_width: usize = 0;
            while (i < self.text.len) {
                const c = self.text[i];
                if (c == '\n') {
                    i += 1;
                    break;
                }
                const char_width = font.width;
                if (line_width + char_width > self.width) break;
                _ = line.append(c) catch break;
                line_width += char_width;
                i += 1;
            }
            lines_buf[lines_count] = line;
            lines_count += 1;
        }

        const line_height: usize = font.height + @as(usize, @intCast(self.line_spacing));
        const total_text_height: usize = lines_count * line_height;

        if (self.text_pos > total_text_height) self.text_pos = self.starting_text_pos;

        const window_y: i32 = self.start_pos.y;
        var text_y: i32 = -@as(i32, self.text_pos);
        for (lines_buf[0..lines_count]) |line| {
            if (text_y + @as(i32, font.height) > 0 and text_y < self.height) {
                var x: u8 = self.start_pos.x;
                for (line.slice()) |char| {
                    const y: i9 = @intCast(window_y + text_y);
                    try draw_char_if_possible(clock, y, x, font, char, self.color);
                    x += font.width;
                }
            }
            text_y += @as(i32, @intCast(line_height));
        }
    }
};
