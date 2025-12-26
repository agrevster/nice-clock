const std = @import("std");
const common = @import("../common.zig");
const loadModuleFromLuau = common.luau.loader.loadModuleFromLuau;

pub const ClockConnectorError = error{ EventLoopAlreadyStarted, NoModules, ClockConfigError };

const logger = std.log.scoped(.common_connector);

/// Used by all clock platforms to handle essential features like modules, fonts and images.
pub const CommonConnector = struct {
    interface: common.Connector.ConnectorInterface,
    has_event_loop_started: bool,
    allocator: std.mem.Allocator,
    image_store: common.image.ImageStore = undefined,
    config: *common.luau.loader.ClockConfig,

    inline fn load_images_for_module(self: *CommonConnector, module: *common.module.ClockModule) void {
        self.image_store.addImagesForModule(module) catch |e| {
            logger.err("Error loading images for module -> {t}", .{e});
        };
    }

    inline fn loadModulesFromConfig(self: *CommonConnector) ClockConnectorError!void {
        self.config.updateClockConfig() catch |e| {
            logger.err("Error loading clock config: {t}", .{e});
            return error.ClockConfigError;
        };
        if (self.config.modules.items.len == 0) return ClockConnectorError.NoModules;
    }

    /// Used to start up the clock, should only be called once
    pub fn startClock(self: *CommonConnector, is_active: *std.atomic.Value(bool)) ClockConnectorError!void {
        if (self.has_event_loop_started) return error.EventLoopAlreadyStarted;
        self.has_event_loop_started = true;

        self.image_store = common.image.ImageStore.init(self.allocator);
        defer self.image_store.deinit();

        var module_arena = std.heap.ArenaAllocator.init(self.allocator);
        defer module_arena.deinit();

        try self.loadModulesFromConfig();

        var current_module = self.config.modules.items[0];
        var modules_ran: u8 = 0;

        //Runs while the clock is running, and doesn't stop till the clock stops
        while (is_active.load(.acquire)) {
            //Only reload the config after `modules_ran` modules have been ran.
            //This improves performance by preventing the config from being reloaded every time.
            if (modules_ran >= common.constants.config_reload_interval) {
                try self.loadModulesFromConfig();
                modules_ran = 0;
            }
            switch (current_module.*) {
                .builtin => |module| {
                    self.load_images_for_module(module);
                    module.render(self, is_active);
                    defer self.image_store.deinitAllImages();
                },
                .custom => |module_filename| {
                    if (!module_arena.reset(.free_all)) logger.err("There was an error freeing module: {s}'s memory!", .{module_filename});
                    if (loadModuleFromLuau(module_filename, module_arena.allocator(), self.config.config)) |module| {
                        self.load_images_for_module(module);
                        module.render(self, is_active);
                        defer self.image_store.deinitAllImages();
                    } else |e| {
                        if (e == error.DebugModule) {
                            logger.warn("Attempted to run a non-module. (This likely means you are debugging)", .{});
                            std.process.exit(1);
                        }
                        logger.err("Error loading file: {s}.luau from Luau: {t}", .{ module_filename, e });
                    }
                },
            }
            const modules = self.config.modules.items;
            self.interface.clearScreen(self.interface.ctx);
            current_module = modules[std.crypto.random.intRangeAtMost(usize, 0, modules.len - 1)];
            modules_ran += 1;
        }
    }
};
