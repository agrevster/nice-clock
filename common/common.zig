const std = @import("std");
const testing = std.testing;

pub const Color = @import("structs/color.zig").ClockColor;
pub const Connector = @import("connectors/connectorInterface.zig");
pub const Clock = @import("connectors/clock.zig").CommonConnector;
pub const ClockError = @import("connectors/clock.zig").ClockConnectorError;
pub const components = @import("structs/components.zig");
pub const font = @import("structs/font.zig");
pub const image = @import("structs/image.zig");
pub const module = @import("structs/module.zig");
pub const constants = @import("constants.zig");

test "Nice Clock Units Tests" {
    testing.refAllDecls(font);
    testing.refAllDecls(components);
    testing.refAllDecls(image);
}
