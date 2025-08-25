const std = @import("std");
const common = @import("common");
const Color = common.Color;
const connector = common.Connector;

pub const SimConnector = struct {
    tile_pointer: *[32][64]Color = undefined,
    blank_tiles: [32][64]Color = undefined,
    tile_cache: [32][64]Color = undefined,

    pub fn connectorInterface(self: *SimConnector) connector.ConnectorInterface {
        return connector.ConnectorInterface{
            .type = connector.ConnectorType.Simulator,
            .setTile = setTile,
            .clearScreen = clearScreen,
            .updateScreen = updateScreen,
            .ctx = self,
        };
    }

    pub fn setTile(ctx: *anyopaque, y: u8, x: u8, color: Color) connector.ConnectorError!void {
        const self: *SimConnector = @ptrCast(@alignCast(ctx));
        if (color.elq(Color{ .r = 0, .g = 0, .b = 0 })) return;

        if (x > 63 or y > 31 or y < 0 or x < 0) {
            std.log.debug("Out of bounds: ({},{})!", .{ y, x });
            return connector.ConnectorError.TileOutOfBounds;
        }
        self.tile_cache[y][x] = color;
    }

    pub fn clearScreen(ctx: *anyopaque) void {
        const self: *SimConnector = @ptrCast(@alignCast(ctx));

        self.tile_cache = self.blank_tiles;
    }

    pub fn updateScreen(ctx: *anyopaque) void {
        const self: *SimConnector = @ptrCast(@alignCast(ctx));

        self.tile_pointer.* = self.tile_cache;
        self.tile_cache = undefined;
    }
};
