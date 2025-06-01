const std = @import("std");
const common = @import("../common.zig");

///Used to specify the creator of the clock module
///`Builtin` => For modules used internally by the clock. Ex error displaying and startup
///`Custom` => For modules created by users.
pub const ClockModuleType = enum {
    Builtin,
    Custom,
};

///The clock is made up of modules, each modules should serve a distinct purpose, ex displaying time.
pub const ClockModule = struct {
    ///The name of the module
    name: []const u8,
    ///The root component used to draw the module.
    root_component: common.components.RootComponent,
    ///How many seconds the module should be active for before switching
    time_limit_s: u64,
    ///The type of the module see: `ClockModuleType`
    module_type: ClockModuleType = ClockModuleType.Custom,
    ///Called whenever a module is initialized, this gives modules a space to make allocations or requests before rendering begins.
    init: ?*const fn (self: *ClockModule, clock: *common.Clock) void,
    ///Called whenever a module is deinitialized, meaning that the module is able to free its allocations.
    deinit: ?*const fn (self: *ClockModule, clock: *common.Clock) void,
    ///Used to tell the clock's image store which images the module needs loaded.
    image_names: ?[]const []const u8,

    const logger = std.log.scoped(.module);

    ///Displays the module on the clock's screen.
    pub fn render(self: *ClockModule, clock: *common.Clock) void {
        if (self.init) |init| init(self, clock);
        self.root_component.render(clock, common.constants.fps, self.time_limit_s) catch |err| {
            logger.err("[{s}]: {s}", .{ self.name, @errorName(err) });
        };
        if (self.deinit) |deinit| deinit(self, clock);
    }
};
