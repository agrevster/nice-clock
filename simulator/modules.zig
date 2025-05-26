const common = @import("common");
const components = common.components;

const red_box = components.BoxComponent{
    .color = common.Color{ .r = 255, .g = 0, .b = 0 },
    .fill_inside = false,
    .pos = components.ComponentPos{ .x = 15, .y = 15 },
    .height = 5,
    .width = 5,
};

const blue_box = components.BoxComponent{
    .color = common.Color{ .b = 255, .g = 0, .r = 0 },
    .fill_inside = false,
    .pos = components.ComponentPos{ .x = 15, .y = 15 },
    .height = 5,
    .width = 5,
};

const letter_a = components.CharComponent{
    .color = common.Color{ .b = 255, .g = 255, .r = 0 },
    .pos = components.ComponentPos{ .x = 10, .y = 10 },
    .char = 'A',
    .font = .Font5x8_2,
};

const hello = components.TextComponent{
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

fn on_animation_update1(clock: *common.Clock, frame_number: u32) void {
    _ = clock;
    _ = frame_number;

    component_animation1.fill_inside = !component_animation1.fill_inside;
}

fn on_animation_update2(clock: *common.Clock, frame_number: u32) void {
    _ = clock;
    const frame_number_u8: u8 = @intCast(frame_number);
    component_animation2.pos.x = frame_number_u8 + 8;
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

pub const animation_module = common.module.ClockModule{
    .name = "Animation",
    .time_limit_s = 10,
    .root_component = components.RootComponent{
        .components = &[_]components.AnyComponent{
            components.AnyComponent{ .animated = animation1 },
            components.AnyComponent{ .animated = animation2 },
        },
    },
};

pub const test_module = common.module.ClockModule{
    .name = "Test",
    .time_limit_s = 5,
    .root_component = components.RootComponent{
        .components = &[_]components.AnyComponent{
            components.AnyComponent{ .normal = red_box.component() },
            components.AnyComponent{ .normal = letter_a.component() },
            components.AnyComponent{ .normal = hello.component() },
        },
    },
};
