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
/// `custom_animation_update` should point to the function that is called whenever the custom animation that this component is part of updates.
///
/// If you need to a access `*@This` in draw use this block
///
/// ```zig
/// const self: *const @This = @ptrCast(@alignCast(ctx));
/// ````
pub const Component = struct {
    ctx: *anyopaque,
    draw: *const fn (ctx: *anyopaque, clock: *Clock) ComponentError!void,
    custom_animation_update: *const fn (ctx: *anyopaque, state: CustomAnimationState) void,
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

///This struct is used to represent a custom clock animation where a user specifies states of the components at a given index.
pub const CustomAnimation = struct {
    ///The indexes of the components you wish to update as part of the custom animation.
    component_indexes: []u9,
    /// The states of the components at the given indexes at a given time stamp.
    states: []CustomAnimationState,
    /// Used to stored the current time stamp value of the custom animation.
    current_timestamp: u32,
    /// The index of the custom animation's state `(states)`.
    current_index: usize,
    ///The maximum value of `current_timestamp`. Think of this like `duration` on normal animations.
    max_timestamp: u32,
    ///Whether or not the animation should start over after `current_timestamp` reaches `max_timestamp`.
    loop: bool,
    ///The speed of the animation larger the speed the slower.
    speed: i16,

    ///Runs custom_animation_update for every child component.
    pub fn updateAllComponents(self: CustomAnimation, components: []const AnyComponent) error{InvalidArgument}!void {
        const state = self.states[self.current_index];
        //Now that we know we need to update update all components.
        for (self.component_indexes) |component_index| {
            //Make sure the component index is a valid one.
            if (component_index >= components.len) {
                logger.err("Invalid component index: {d}. Components len: {d}", .{ component_index, components.len });
                return error.InvalidArgument;
            }

            //Update the component
            switch (components[component_index]) {
                .normal => |component| component.custom_animation_update(component.ctx, state),
                .animated => |animated| animated.component.custom_animation_update(animated.component.ctx, state),
            }
        }
    }
};

///Used to represent the state of the animation at a given time stamp.
pub const CustomAnimationState = struct {
    ///The time stamp where the animation state should be applied.
    timestamp: u32,
    ///The color state of all components part of this animation.
    color: ?Color = null,
    ///The pos state of all components part of this animation.
    pos: ?ComponentPos = null,
    ///The text state of all components part of this animation.
    text: ?[]const u8 = null,
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
    ///The list of all the components inside of the root.
    components: []const AnyComponent,
    ///Used to create custom animations via specifying the state of given components at a given time.
    custom_animations: []common.components.CustomAnimation,

    ///Returns the speed of the fastest child's animation updates or `null` if there are no animated components. *or animated components with 0 as speed*
    fn getFastestAnimationSpeed(self: *RootComponent) ?i16 {
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
    pub fn render(self: *RootComponent, clock: *Clock, fps: u8, time_limit_s: u64, is_active: *std.atomic.Value(bool)) ComponentError!void {
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

        //Used to track how long the module has been running for
        var module_active_timer = try std.time.Timer.start();
        //Used to track how long it took to process the module, so we can subtract it from the time required to achieve N FPS.
        var processing_timer = try std.time.Timer.start();
        var frame: u32 = 0;

        module_active_timer.reset();

        while (is_active.load(.seq_cst)) {
            processing_timer.reset();
            if ((module_active_timer.read() / time.ns_per_s) > time_limit_s) break;
            clock.interface.clearScreen(clock.interface.ctx);

            //Before we draw hardcoded animated components we need to do the custom ones so they can move the normal ones around.
            for (self.custom_animations) |*animation| {
                if (animation.current_timestamp > animation.max_timestamp) {
                    if (!animation.loop) continue;
                    animation.current_timestamp = 0;
                    animation.current_index = 0;
                    try animation.updateAllComponents(self.components);
                }

                //I copied this from my earlier update animation code from TimedAnimation.
                if (animation.speed > 0 and frame % @as(u32, @intCast(animation.speed)) == 0) {
                    animation.current_timestamp += 1;

                    if (animation.current_index >= animation.states.len) {
                        logger.err("The index marked as current state: {d} >= all size of the states list: {d}.", .{ animation.current_index, animation.states.len });
                        return error.InvalidArgument;
                    }

                    //Do we need to update?
                    if (animation.current_index + 1 < animation.states.len and animation.current_timestamp >= animation.states[animation.current_index + 1].timestamp) {
                        animation.current_index += 1;
                        try animation.updateAllComponents(self.components);
                    }
                }
            }

            // Update + draw hardcoded animated components
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
            const runtime = processing_timer.read();
            if (runtime < sleep_time_ns) {
                std.Thread.sleep(sleep_time_ns - runtime);
            }
        }
    }
};

///Used to represent single tiles on the screen, at position `pos` and of color `color`.
pub const TileComponent = struct {
    pos: ComponentPos,
    color: Color,

    pub fn component(self: *TileComponent) Component {
        return Component{ .ctx = self, .draw = &draw, .custom_animation_update = &custom_animation_update };
    }

    pub fn from_luau(args: []LuauArg, allocator: std.mem.Allocator) LuauComponentConstructorError!*AnyComponent {
        const pos = try LuauArg.getPosOrError(args, 0);
        const color = try LuauArg.getColorOrError(args, 1);

        const comp = allocator.create(TileComponent) catch return LuauComponentConstructorError.MemoryError;
        const ret = allocator.create(AnyComponent) catch return LuauComponentConstructorError.MemoryError;

        comp.* = TileComponent{ .pos = pos, .color = color };
        ret.* = AnyComponent{ .normal = comp.*.component() };
        return ret;
    }

    fn custom_animation_update(ctx: *anyopaque, state: CustomAnimationState) void {
        const self: *TileComponent = @ptrCast(@alignCast(ctx));
        if (state.color) |c| self.color = c;
        if (state.pos) |p| self.pos = p;
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
        return Component{ .ctx = self, .draw = &draw, .custom_animation_update = &custom_animation_update };
    }

    pub fn from_luau(args: []LuauArg, allocator: std.mem.Allocator) LuauComponentConstructorError!*AnyComponent {
        const pos = try LuauArg.getPosOrError(args, 0);
        const width = try LuauArg.getU8IntOrError(args, 1);
        const height = try LuauArg.getU8IntOrError(args, 2);
        const fill_inside = try LuauArg.getBoolOrError(args, 3);
        const color = try LuauArg.getColorOrError(args, 4);

        const comp = allocator.create(BoxComponent) catch return LuauComponentConstructorError.MemoryError;
        const ret = allocator.create(AnyComponent) catch return LuauComponentConstructorError.MemoryError;

        comp.* = BoxComponent{ .pos = pos, .color = color, .width = width, .height = height, .fill_inside = fill_inside };
        ret.* = AnyComponent{ .normal = comp.*.component() };
        return ret;
    }

    fn custom_animation_update(ctx: *anyopaque, state: CustomAnimationState) void {
        const self: *BoxComponent = @ptrCast(@alignCast(ctx));
        if (state.color) |c| self.color = c;
        if (state.pos) |p| self.pos = p;
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
        return Component{ .ctx = self, .draw = &draw, .custom_animation_update = &custom_animation_update };
    }

    pub fn from_luau(args: []LuauArg, allocator: std.mem.Allocator) LuauComponentConstructorError!*AnyComponent {
        const pos = try LuauArg.getPosOrError(args, 0);
        const radius = try LuauArg.getU8IntOrError(args, 1);
        const outline_thickness = try LuauArg.getU8IntOrError(args, 2);
        const color = try LuauArg.getColorOrError(args, 3);

        const comp = allocator.create(CircleComponent) catch return LuauComponentConstructorError.MemoryError;
        const ret = allocator.create(AnyComponent) catch return LuauComponentConstructorError.MemoryError;

        comp.* = CircleComponent{ .pos = pos, .color = color, .radius = radius, .outline_thickness = outline_thickness };
        ret.* = AnyComponent{ .normal = comp.*.component() };
        return ret;
    }

    fn custom_animation_update(ctx: *anyopaque, state: CustomAnimationState) void {
        const self: *CircleComponent = @ptrCast(@alignCast(ctx));
        if (state.color) |c| self.color = c;
        if (state.pos) |p| self.pos = p;
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

    for (0..@min(glyph.len, font.height)) |row| {
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
        return Component{ .ctx = self, .draw = &draw, .custom_animation_update = &custom_animation_update };
    }

    fn custom_animation_update(ctx: *anyopaque, state: CustomAnimationState) void {
        const self: *CharComponent = @ptrCast(@alignCast(ctx));
        if (state.color) |c| self.color = c;
        if (state.pos) |p| self.pos = p;
    }

    pub fn from_luau(args: []LuauArg, allocator: std.mem.Allocator) LuauComponentConstructorError!*AnyComponent {
        const pos = try LuauArg.getPosOrError(args, 0);
        const font = try LuauArg.getFontOrError(args, 1);
        const char = try LuauArg.getCharOrError(args, 2);
        const color = try LuauArg.getColorOrError(args, 3);

        const comp = allocator.create(CharComponent) catch return LuauComponentConstructorError.MemoryError;
        const ret = allocator.create(AnyComponent) catch return LuauComponentConstructorError.MemoryError;

        comp.* = CharComponent{ .pos = pos, .color = color, .font = font, .char = char };
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
        return Component{ .ctx = self, .draw = &draw, .custom_animation_update = &custom_animation_update };
    }

    pub fn from_luau(args: []LuauArg, allocator: std.mem.Allocator) LuauComponentConstructorError!*AnyComponent {
        const pos = try LuauArg.getPosOrError(args, 0);
        const font = try LuauArg.getFontOrError(args, 1);
        const text_arg = try LuauArg.getStringOrError(args, 2);
        const color = try LuauArg.getColorOrError(args, 3);

        const comp = allocator.create(TextComponent) catch return LuauComponentConstructorError.MemoryError;
        const ret = allocator.create(AnyComponent) catch return LuauComponentConstructorError.MemoryError;
        const text = allocator.dupeZ(u8, text_arg) catch return LuauComponentConstructorError.MemoryError;

        std.mem.copyForwards(u8, text, text_arg);

        comp.* = TextComponent{ .pos = pos, .color = color, .font = font, .text = text };
        ret.* = AnyComponent{ .normal = comp.*.component() };
        return ret;
    }

    fn custom_animation_update(ctx: *anyopaque, state: CustomAnimationState) void {
        const self: *TextComponent = @ptrCast(@alignCast(ctx));
        if (state.color) |c| self.color = c;
        if (state.pos) |p| self.pos = p;
        if (state.text) |t| self.text = t;
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
        return Component{ .ctx = self, .draw = &draw, .custom_animation_update = &custom_animation_update };
    }

    pub fn from_luau(args: []LuauArg, allocator: std.mem.Allocator) LuauComponentConstructorError!*AnyComponent {
        const pos = try LuauArg.getPosOrError(args, 0);
        const font = try LuauArg.getFontOrError(args, 1);
        const text_arg = try LuauArg.getStringOrError(args, 2);
        const color = try LuauArg.getColorOrError(args, 3);
        const line_spacing = try LuauArg.getI8IntOrError(args, 4);

        const text = allocator.dupeZ(u8, text_arg) catch return LuauComponentConstructorError.MemoryError;
        const comp = allocator.create(WrappedTextComponent) catch return LuauComponentConstructorError.MemoryError;
        const ret = allocator.create(AnyComponent) catch return LuauComponentConstructorError.MemoryError;

        std.mem.copyForwards(u8, text, text_arg);

        comp.* = WrappedTextComponent{ .pos = pos, .color = color, .font = font, .text = text, .line_spacing = line_spacing };
        ret.* = AnyComponent{ .normal = comp.*.component() };
        return ret;
    }

    fn custom_animation_update(ctx: *anyopaque, state: CustomAnimationState) void {
        const self: *WrappedTextComponent = @ptrCast(@alignCast(ctx));
        if (state.color) |c| self.color = c;
        if (state.pos) |p| self.pos = p;
        if (state.text) |t| self.text = t;
    }

    ///Allows for addition of negative i8 `spacing` to u8 `initial`.
    ///*If the number is negative returns `0`*
    //This is pretty clumsy but it does the job, and fingers crossed no one will overflow because the screen is only 64x32
    fn processSpacing(initial: u8, spacing: i8) u8 {
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
                y += processSpacing(font.height, self.line_spacing);
                x = self.pos.x;
                continue;
            }

            if (x + font.width >= 64) {
                x = self.pos.x;

                y += processSpacing(font.height, self.line_spacing);

                if (y > 31 - font.height) break; //We don't want to draw text off the screen
            }
            try draw_char(clock, y, x, font, char, self.color);
            x += font.width;
        }
    }
};

///Used to draw an image onto the screen.
///Setting image_name to empty draws nothing
pub const ImageComponent = struct {
    pos: ComponentPos,
    image_name: []const u8,

    pub fn component(self: *ImageComponent) Component {
        return Component{ .ctx = self, .draw = &draw, .custom_animation_update = &custom_animation_update };
    }

    pub fn from_luau(args: []LuauArg, allocator: std.mem.Allocator) LuauComponentConstructorError!*AnyComponent {
        const pos = try LuauArg.getPosOrError(args, 0);
        const image_name_arg = try LuauArg.getStringOrError(args, 1);

        const image_name = allocator.dupeZ(u8, image_name_arg) catch return LuauComponentConstructorError.MemoryError;
        const comp = allocator.create(ImageComponent) catch return LuauComponentConstructorError.MemoryError;
        const ret = allocator.create(AnyComponent) catch return LuauComponentConstructorError.MemoryError;

        std.mem.copyForwards(u8, image_name, image_name_arg);
        comp.* = ImageComponent{ .pos = pos, .image_name = image_name };
        ret.* = AnyComponent{ .normal = comp.*.component() };
        return ret;
    }

    fn custom_animation_update(ctx: *anyopaque, state: CustomAnimationState) void {
        const self: *ImageComponent = @ptrCast(@alignCast(ctx));
        if (state.pos) |p| self.pos = p;
        if (state.text) |t| {
            self.image_name = t;
        }
    }

    const black = common.Color{ .r = 0, .g = 0, .b = 0 };

    fn draw(ctx: *anyopaque, clock: *Clock) ComponentError!void {
        const self: *const ImageComponent = @ptrCast(@alignCast(ctx));

        if (std.mem.eql(u8, "empty", self.image_name)) return;

        const image = try clock.image_store.getImage(self.image_name);

        for (0..image.height) |y| {
            const y_u8: u8 = @intCast(y);
            for (0..image.width) |x| {
                const x_u8: u8 = @intCast(x);
                const pixel = image.pixels[y * image.width + x];
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
        return Component{ .ctx = self, .draw = &draw, .custom_animation_update = &custom_animation_update };
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
        const start_pos = try LuauArg.getPosOrError(args, 0);
        const font = try LuauArg.getFontOrError(args, 1);
        const text_arg = try LuauArg.getStringOrError(args, 2);
        const color = try LuauArg.getColorOrError(args, 3);
        const cutoff_x = try LuauArg.getU8IntOrError(args, 4);
        const text_pos = try LuauArg.getI32IntOrError(args, 5);
        const animation_arg = try LuauArg.getAnimationOrError(args, 6);

        if (start_pos.x < cutoff_x) {
            logger.err("x pos should be greater than cutoff x!", .{});
            return LuauComponentConstructorError.ValidationError;
        }

        const text = allocator.dupeZ(u8, text_arg) catch return LuauComponentConstructorError.MemoryError;
        const comp = allocator.create(HorizontalScrollingTextComponent) catch return LuauComponentConstructorError.MemoryError;
        const ret = allocator.create(AnyComponent) catch return LuauComponentConstructorError.MemoryError;

        std.mem.copyForwards(u8, text, text_arg);

        comp.* = HorizontalScrollingTextComponent{
            .start_pos = start_pos,
            .color = color,
            .font = font,
            .text = text,
            .text_pos = text_pos,
            .cutoff_x = cutoff_x,
        };
        ret.* = AnyComponent{ .animated = comp.*.animation(animation_arg.duration, animation_arg.loop, animation_arg.speed) };
        return ret;
    }

    fn custom_animation_update(ctx: *anyopaque, state: CustomAnimationState) void {
        const self: *HorizontalScrollingTextComponent = @ptrCast(@alignCast(ctx));
        if (state.color) |c| self.color = c;
        if (state.pos) |p| self.start_pos = p;
        if (state.text) |t| self.text = t;
    }

    fn update_animation(ctx: *anyopaque, clock: *Clock, frame_number: u32) void {
        const comp: *HorizontalScrollingTextComponent = @ptrCast(@alignCast(ctx));
        _ = clock;
        _ = frame_number;
        comp.text_pos += 1;
    }

    fn drawCharColumnIfPossible(clock: *Clock, y_pos: u8, x_pos: u8, font: common.font.BDF, char: u8, column: u8, color: Color) ComponentError!void {
        if (y_pos > 31 or x_pos > 64) return;
        if (column >= font.width) return;
        const glyph = font.glyphs.get(char) orelse font.glyphs.get(font.default_char).?;
        const bytes_per_row = (font.width + 7) / 8;

        for (0..@min(glyph.len, font.height)) |row| {
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

    fn getCharAndY(text: []const u8, font: common.font.BDF, text_pixel_x: usize) ?[2]usize {
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

            if (getCharAndY(self.text, font, text_pixel_x_usize)) |info| {
                const x_u8: u8 = @intCast(x);
                const column: u8 = @truncate(info[1]);
                try drawCharColumnIfPossible(clock, self.start_pos.y, x_u8, font, self.text[info[0]], column, self.color);
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
    lines: [][]const u8,
    color: Color,
    text_pos: i32 = 0,
    starting_text_pos: i32 = 0,
    line_spacing: u8,

    ///WARNING: This is for internal use only. If you want to draw this use animation()
    fn component(self: *VerticalScrollingTextComponent) Component {
        return Component{ .ctx = self, .draw = &draw, .custom_animation_update = &custom_animation_update };
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
        const start_pos = try LuauArg.getPosOrError(args, 0);
        const width = try LuauArg.getU8IntOrError(args, 1);
        const height = try LuauArg.getU8IntOrError(args, 2);
        const font = try LuauArg.getFontOrError(args, 3);
        const text_arg = try LuauArg.getStringOrError(args, 4);
        const color = try LuauArg.getColorOrError(args, 5);
        const text_pos = try LuauArg.getI32IntOrError(args, 6);
        const line_spacing = try LuauArg.getU8IntOrError(args, 7);
        const animation_arg = try LuauArg.getAnimationOrError(args, 8);

        const text = allocator.dupeZ(u8, text_arg) catch return LuauComponentConstructorError.MemoryError;
        const comp = allocator.create(VerticalScrollingTextComponent) catch return LuauComponentConstructorError.MemoryError;
        const ret = allocator.create(AnyComponent) catch return LuauComponentConstructorError.MemoryError;

        std.mem.copyForwards(u8, text, text_arg);

        //Precompute lines
        var lines_list = std.ArrayList([]const u8).empty;
        errdefer lines_list.deinit(allocator);

        var i: usize = 0;
        const font_data = font.font() catch {
            logger.err("Invalid font!", .{});
            return LuauComponentConstructorError.OtherError;
        };

        while (i < text.len) {
            var line = std.ArrayList(u8).initCapacity(allocator, 32) catch return LuauComponentConstructorError.MemoryError;
            errdefer line.deinit(allocator);
            var line_width: usize = 0;
            while (i < text.len) {
                const c = text[i];
                if (c == '\n') {
                    i += 1;
                    break;
                }
                const char_width = font_data.width;
                if (line_width + char_width > width) break;
                _ = line.appendBounded(c) catch break;
                line_width += char_width;
                i += 1;
            }
            lines_list.append(allocator, line.toOwnedSlice(allocator) catch return LuauComponentConstructorError.MemoryError) catch return LuauComponentConstructorError.MemoryError;
        }

        comp.* = VerticalScrollingTextComponent{
            .start_pos = start_pos,
            .color = color,
            .font = font,
            .text = text,
            .starting_text_pos = text_pos,
            .lines = lines_list.toOwnedSlice(allocator) catch return LuauComponentConstructorError.MemoryError,
            .text_pos = text_pos,
            .width = width,
            .height = height,
            .line_spacing = line_spacing,
        };
        ret.* = AnyComponent{ .animated = comp.*.animation(animation_arg.duration, animation_arg.loop, animation_arg.speed) };
        return ret;
    }

    fn custom_animation_update(ctx: *anyopaque, state: CustomAnimationState) void {
        const self: *VerticalScrollingTextComponent = @ptrCast(@alignCast(ctx));
        if (state.color) |c| self.color = c;
        if (state.pos) |p| self.start_pos = p;
        if (state.text) |t| self.text = t;
    }

    fn update_animation(ctx: *anyopaque, clock: *Clock, frame_number: u32) void {
        const comp: *VerticalScrollingTextComponent = @ptrCast(@alignCast(ctx));
        _ = clock;
        _ = frame_number;
        comp.text_pos += 1;
    }

    fn drawCharIfPossible(clock: *Clock, y_pos: i9, x_pos: i9, font: common.font.BDF, char: u8, color: Color) ComponentError!void {
        if (y_pos < -@as(i9, @intCast(font.height))) return;
        const glyph = font.glyphs.get(char) orelse font.glyphs.get(font.default_char).?;
        const bytes_per_row = (font.width + 7) / 8;

        for (0..@min(glyph.len, font.height)) |row| {
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

        const line_height: usize = font.height + @as(usize, @intCast(self.line_spacing));
        const line_count = self.lines.len;
        const total_text_height: usize = line_count * line_height;

        if (self.text_pos > total_text_height) self.text_pos = self.starting_text_pos;

        const window_y: i32 = self.start_pos.y;
        var text_y: i32 = -@as(i32, self.text_pos);
        for (self.lines[0..line_count]) |line| {
            if (text_y + @as(i32, font.height) > 0 and text_y < self.height) {
                var x: u8 = self.start_pos.x;
                for (line) |char| {
                    const y: i9 = @intCast(window_y + text_y);
                    try drawCharIfPossible(clock, y, x, font, char, self.color);
                    x += font.width;
                }
            }
            text_y += @as(i32, @intCast(line_height));
        }
    }
};
