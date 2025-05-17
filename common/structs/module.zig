const std = @import("std");
const common = @import("common");

pub const ClockModuleType = enum {
    Internal,
    Builtin,
    Custom,
};

pub const ClockModule = struct {
    name: []u8,
    root_component: common.components.RootComponent,
    clock: *common.Connector,
    time_limit: u64,
    module_type: ClockModuleType = ClockModuleType.Custom,

    const logger = std.log.scoped(.module);

    pub fn render(self: *ClockModule) void {
        self.root_component.render(self.clock, common.constants.fps, self.time_limit) catch |err| {
            logger.err("[{s}] - ", .{ self.name, @TypeOf(err) });
        };
    }
};
