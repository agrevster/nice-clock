const common = @import("common");

pub const ConnectorError = error{
    TileOutOfBounds,
};

pub const ConnectorType = enum { Simulator, Hardware };

pub const ConnectorInterface = struct {
    type: ConnectorType,
    ctx: *anyopaque,

    setTile: *const fn (ctx: *anyopaque, y: u8, x: u8, color: common.Color) ConnectorError!void,
    updateScreen: *const fn (ctx: *anyopaque) void,
    clearScreen: *const fn (ctx: *anyopaque) void,
};
