const std = @import("std");
const common = @import("common");
const components = common.components;

var red_box = components.BoxComponent{
    .color = common.Color{ .r = 255, .g = 0, .b = 0 },
    .fill_inside = false,
    .pos = components.ComponentPos{ .x = 15, .y = 15 },
    .height = 5,
    .width = 5,
};

var blue_box = components.BoxComponent{
    .color = common.Color{ .b = 255, .g = 0, .r = 0 },
    .fill_inside = false,
    .pos = components.ComponentPos{ .x = 15, .y = 15 },
    .height = 5,
    .width = 5,
};

var letter_a = components.CharComponent{
    .color = common.Color{ .b = 255, .g = 255, .r = 0 },
    .pos = components.ComponentPos{ .x = 10, .y = 10 },
    .char = 'A',
    .font = .Font5x8_2,
};

var hello = components.TextComponent{
    .color = common.Color{ .b = 255, .g = 0, .r = 255 },
    .pos = components.ComponentPos{ .x = 5, .y = 20 },
    .text = "Hello",
    .font = .Font5x8,
};

var component_animation2 = components.TextComponent{
    .color = common.Color{ .b = 0, .g = 0, .r = 255 },
    .pos = components.ComponentPos{ .x = 5, .y = 20 },
    .text = ":)",
    .font = .Font6x12,
};

var component_animation1 = components.BoxComponent{
    .color = common.Color{ .b = 255, .g = 255, .r = 0 },
    .fill_inside = false,
    .height = 10,
    .width = 10,
    .pos = components.ComponentPos{ .x = 20, .y = 10 },
};

fn on_animation_update1(ctx: *anyopaque, clock: *common.Clock, frame_number: u32) void {
    _ = clock;
    _ = frame_number;

    const component: *components.BoxComponent = @ptrCast(@alignCast(ctx));
    component.fill_inside = !component.fill_inside;
}

fn on_animation_update2(ctx: *anyopaque, clock: *common.Clock, frame_number: u32) void {
    _ = clock;
    const component: *components.TextComponent = @ptrCast(@alignCast(ctx));
    const frame_number_u8: u8 = @intCast(frame_number);
    component.pos.x = frame_number_u8 + 8;
}

const animation1 = components.AnimationComponent{
    .component = component_animation1.component(),
    .loop = true,
    .duration = 5,
    .speed = 10,
    .update_animation = &on_animation_update1,
};

const animation2 = components.AnimationComponent{
    .component = component_animation2.component(),
    .loop = true,
    .duration = 10,
    .speed = 40,
    .update_animation = &on_animation_update2,
};

var test_image_component = components.ImageComponent{
    .pos = components.ComponentPos{ .x = 40, .y = 10 },
    .image_name = "test",
};

var long_text = components.WrappedTextComponent{
    .color = common.Color{ .b = 0, .g = 0, .r = 255 },
    .pos = components.ComponentPos{ .x = 3, .y = 1 },
    .text = "Big 4L, I'm a member (yeah) Leave an opp cold, like December (what?) .45 on me, it's a Kimber (and what?) AK knockin' down trees, like timber",
    .font = .Font5x8,
    .line_spacing = -1,
};

const animation_module = common.module.ClockModule{
    .name = "Animation",
    .time_limit_s = 10,
    .init = null,
    .deinit = null,
    .image_names = null,
    .root_component = components.RootComponent{
        .components = &[_]components.AnyComponent{
            components.AnyComponent{ .animated = animation1 },
            components.AnyComponent{ .animated = animation2 },
        },
    },
};

const test_module = common.module.ClockModule{
    .name = "Test",
    .time_limit_s = 5,
    .init = null,
    .deinit = null,
    .image_names = &[_][]const u8{"test"},
    .root_component = components.RootComponent{
        .components = &[_]components.AnyComponent{
            components.AnyComponent{ .normal = red_box.component() },
            components.AnyComponent{ .normal = letter_a.component() },
            components.AnyComponent{ .normal = hello.component() },
            components.AnyComponent{ .normal = test_image_component.component() },
        },
    },
};

const long_text_module = common.module.ClockModule{
    .name = "Long Text Test",
    .time_limit_s = 10,
    .init = null,
    .deinit = null,
    .image_names = null,
    .root_component = components.RootComponent{
        .components = &[_]components.AnyComponent{
            components.AnyComponent{ .normal = long_text.component() },
        },
    },
};

const logger = std.log.scoped(.test_module_loader);

var modules: []common.module.ClockModule = undefined;

fn unload(allocator: *std.mem.Allocator) void {
    allocator.free(modules);
}
fn load(allocator: *std.mem.Allocator) []common.module.ClockModule {
    if (allocator.alloc(common.module.ClockModule, 3)) |m| {
        modules = m;
    } else |err| {
        logger.err("{s}", .{@errorName(err)});
    }
    errdefer allocator.free(modules);

    modules[0] = long_text_module;
    modules[1] = animation_module;
    modules[2] = test_module;
    return modules;
}

pub fn TestModuleLoader() common.module_loader.ModuleLoaderInterface {
    return common.module_loader.ModuleLoaderInterface{ .unload = &unload, .load = &load };
}
