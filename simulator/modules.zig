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

pub const test_module = common.module.ClockModule{
    .name = "Test",
    .time_limit_s = 5,
    .root_component = components.RootComponent{
        .components = &[_]components.Component{
            red_box.component(),
            letter_a.component(),
        },
    },
};
