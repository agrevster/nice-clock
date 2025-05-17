const std = @import("std");
const testing = std.testing;

pub const Color = @import("structs/color.zig").ClockColor;
pub const Connector = @import("connectors/connectorInterface.zig");
pub const Clock = @import("connectors/commonConnector.zig").CommonConnector;
pub const ClockError = @import("connectors/commonConnector.zig").ClockConnectorError;
pub const components = @import("structs/components.zig");
pub const BDF = @import("structs/bdf.zig").BDF;
pub const module = @import("structs/module.zig");
pub const constants = @import("constants.zig");

test "Nice Clock Units Tests" {
    testing.refAllDecls(BDF);
}
