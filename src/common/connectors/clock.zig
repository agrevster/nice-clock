const std = @import("std");
const common = @import("../common.zig");
const loadModuleFromLuau = common.luau.loader.loadModuleFromLuau;

pub const ClockConnectorError = error{ EventLoopAlreadyStarted, NoModules };

const logger = std.log.scoped(.common_connector);

/// Used by all clock platforms to handle essential features like modules, fonts and images.
pub const CommonConnector = struct {
    interface: common.Connector.ConnectorInterface,
    has_event_loop_started: bool,
    modules: []const common.module.ClockModuleSource,
    allocator: std.mem.Allocator,
    image_store: common.image.ImageStore = undefined,

    inline fn load_images_for_module(self: *CommonConnector, module: *common.module.ClockModule) void {
        self.image_store.addImagesForModule(module) catch |e| {
            logger.err("Error loading images for module -> {s}", .{@errorName(e)});
        };
    }

    /// Used to start up the clock, should only be called once
    pub fn startClock(self: *CommonConnector, is_active: *bool) ClockConnectorError!void {
        if (self.has_event_loop_started) return ClockConnectorError.EventLoopAlreadyStarted;
        self.has_event_loop_started = true;

        if (self.modules.len == 0) return ClockConnectorError.NoModules;

        self.image_store = common.image.ImageStore.init(self.allocator);
        defer self.image_store.deinit();

        var current_module = self.modules[0];

        while (is_active.*) {
            switch (current_module) {
                .builtin => |module| {
                    self.load_images_for_module(module);
                    module.render(self);
                    defer self.image_store.deinitAllImages();
                },
                .custom => |module_filename| {
                    if (loadModuleFromLuau(module_filename, self.allocator)) |module| {
                        self.load_images_for_module(module);
                        module.render(self);
                        defer self.image_store.deinitAllImages();
                        defer self.allocator.destroy(module);
                    } else |e| {
                        if (e == error.DebugModule) {
                            logger.warn("Attempted to run a non-module. (This likely means you are debugging)", .{});
                            std.process.exit(1);
                        }
                        logger.err("Error loading file: {s}.luau from Luau: {s}", .{ module_filename, @errorName(e) });
                    }
                },
            }
            self.interface.clearScreen(self.interface.ctx);
            current_module = self.modules[std.crypto.random.intRangeAtMost(usize, 0, self.modules.len - 1)];
        }
    }
};
