const common = @import("common");
const components = common.components;

const box = components.BoxComponent{
    .color = common.Color{ .r = 255, .g = 0, .b = 0 },
    .fill_inside = false,
    .pos = components.ComponentPos{ .x = 15, .y = 15 },
    .height = 5,
    .width = 5,
};
const module_components = [_]components.Component{box.component()};

pub const test_module = common.module.ClockModule{ .name = "Test", .time_limit = 5000, .root_component = components.RootComponent{ .components = &module_components } };
