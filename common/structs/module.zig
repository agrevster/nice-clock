const std = @import("std");
const common = @import("../common.zig");

pub const ClockModuleType = enum {
    Internal,
    Builtin,
    Custom,
};

pub const ClockModule = struct {
    name: []const u8,
    root_component: common.components.RootComponent,
    time_limit_s: u64,
    module_type: ClockModuleType = ClockModuleType.Custom,

    const logger = std.log.scoped(.module);

    pub fn render(self: *ClockModule, clock: *common.Clock) void {
        self.root_component.render(clock, common.constants.fps, self.time_limit_s) catch |err| {
            logger.err("[{s}] - {}", .{ self.name, @TypeOf(err) });
        };
    }
};
