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

    const logger = std.log.scoped(.module);

    ///Displays the module on the clock's screen.
    pub fn render(self: *ClockModule, clock: *common.Clock, allocator: std.mem.Allocator) void {
        self.root_component.render(clock, common.constants.fps, self.time_limit_s, allocator) catch |err| {
            logger.err("[{s}]: {s}", .{ self.name, @errorName(err) });
            clock.has_event_loop_started = false;
        };
    }
};
