const std = @import("std");
const common = @import("../common.zig");

pub const ClockConnectorError = error{ EventLoopAlreadyStarted, NoModules };

const logger = std.log.scoped(.common_connector);

/// Used by all clock platforms to handle essential features like modules, fonts and images.
pub const CommonConnector = struct {
    interface: common.Connector.ConnectorInterface,
    has_event_loop_started: bool,
    modules: []common.module.ClockModule,
    allocator: std.mem.Allocator,
    image_store: common.image.ImageStore = undefined,

    /// Used to start up the clock, should only be called once
    pub fn startClock(self: *CommonConnector, is_active: *bool) ClockConnectorError!void {
        if (self.has_event_loop_started) return ClockConnectorError.EventLoopAlreadyStarted;
        self.has_event_loop_started = true;

        if (self.modules.len == 0) return ClockConnectorError.NoModules;

        self.image_store = common.image.ImageStore.init(self.allocator);
        defer self.image_store.deinit();

        var current_module = self.modules[0];

        while (is_active.*) {
            self.image_store.addImagesForModule(&current_module) catch |e| {
                logger.err("Error loading images for module -> {s}", .{@errorName(e)});
            };
            defer self.image_store.deinitAllImages();
            current_module.render(self);
            self.interface.clearScreen(self.interface.ctx);
            current_module = self.modules[std.crypto.random.intRangeAtMost(usize, 0, self.modules.len - 1)];
        }
    }
};
