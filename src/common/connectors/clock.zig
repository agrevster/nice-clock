const std = @import("std");
const common = @import("../common.zig");

pub const ClockConnectorError = error{ EventLoopAlreadyStarted, NoModules };

const logger = std.log.scoped(.common_connector);

/// Used by all clock platforms to handle essential features like modules, fonts and images.
pub const CommonConnector = struct {
    interface: common.Connector.ConnectorInterface,
    has_event_loop_started: bool,
    module_loader: common.module_loader.ModuleLoaderInterface,
    allocator: std.mem.Allocator,
    image_store: common.image.ImageStore = undefined,

    /// Used to start up the clock, should only be called once
    pub fn startClock(self: *CommonConnector, is_active: *bool) ClockConnectorError!void {
        if (self.has_event_loop_started) return ClockConnectorError.EventLoopAlreadyStarted;
        self.has_event_loop_started = true;

        const modules = self.module_loader.load(&self.allocator);
        defer self.module_loader.unload(&self.allocator);
        if (modules.len == 0) return ClockConnectorError.NoModules;

        self.image_store = common.image.ImageStore.init(self.allocator);
        defer self.image_store.deinit();

        var current_module = modules[0];

        while (is_active.*) {
            self.image_store.add_images_for_module(&current_module) catch |e| {
                logger.err("Error loading images for module -> {s}", .{@errorName(e)});
            };
            defer self.image_store.deinit_all_images();
            current_module.render(self);
            self.interface.clearScreen(self.interface.ctx);
            current_module = modules[std.crypto.random.intRangeAtMost(usize, 0, modules.len - 1)];
        }
    }
};
