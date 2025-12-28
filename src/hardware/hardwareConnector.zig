const std = @import("std");
const common = @import("common");
const Color = common.Color;
const connector = common.Connector;
const driver = @cImport({
    @cInclude("led-matrix-c.h");
});

pub const HardwareConnector = struct {
    allocator: std.mem.Allocator = std.heap.page_allocator,
    matrix: ?*driver.RGBLedMatrix = undefined,
    options: *driver.RGBLedMatrixOptions = undefined,
    tile_cache: ?*driver.LedCanvas = undefined,

    pub fn init(self: *HardwareConnector) !void {
        errdefer deinit(self);
        self.options = try self.allocator.create(driver.RGBLedMatrixOptions);
        self.options.* = .{
            .chain_length = 1,
            .rows = 32,
            .cols = 64,
            .limit_refresh_rate_hz = 65,
            .hardware_mapping = "adafruit-hat",
            .disable_hardware_pulsing = true,
        };

        self.matrix = driver.led_matrix_create_from_options(self.options, 0, null);
        self.tile_cache = driver.led_matrix_create_offscreen_canvas(self.matrix);
    }

    pub fn deinit(self: *HardwareConnector) void {
        self.allocator.destroy(self.options);
        driver.led_matrix_delete(self.matrix);
    }

    pub fn connectorInterface(self: *HardwareConnector) connector.ConnectorInterface {
        return connector.ConnectorInterface{
            .type = connector.ConnectorType.Hardware,
            .setTile = setTile,
            .clearScreen = clearScreen,
            .updateScreen = updateScreen,
            .ctx = self,
        };
    }

    pub fn setTile(ctx: *anyopaque, y: u8, x: u8, color: Color) connector.ConnectorError!void {
        const self: *HardwareConnector = @ptrCast(@alignCast(ctx));
        if (color.elq(Color{ .r = 0, .g = 0, .b = 0 })) return;

        if (x > 63 or y > 31 or y < 0 or x < 0) {
            std.log.debug("Out of bounds: ({},{})!", .{ y, x });
            return connector.ConnectorError.TileOutOfBounds;
        }
        driver.led_canvas_set_pixel(self.tile_cache, x, y, color.r, color.b, color.g);
    }

    pub fn clearScreen(ctx: *anyopaque) void {
        const self: *HardwareConnector = @ptrCast(@alignCast(ctx));
        driver.led_canvas_clear(self.tile_cache);
    }

    pub fn updateScreen(ctx: *anyopaque) void {
        const self: *HardwareConnector = @ptrCast(@alignCast(ctx));
        self.tile_cache = driver.led_matrix_swap_on_vsync(self.matrix, self.tile_cache);
    }


    pub fn setBrightness(ctx: *anyopaque, brightness: u8) void {
        const self: *HardwareConnector = @ptrCast(@alignCast(ctx));
        driver.led_matrix_set_brightness(self.matrix, self.brightness);
    }

};
