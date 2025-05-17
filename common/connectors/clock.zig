const std = @import("std");
const common = @import("../common.zig");

pub const ClockConnectorError = error{EventLoopAlreadyStarted};

pub const CommonConnector = struct {
    interface: common.Connector.ConnectorInterface,
    has_event_loop_started: bool,
    modules: []const common.module.ClockModule,

    pub fn startClock(self: *CommonConnector, is_active: *bool) ClockConnectorError!void {
        if (self.has_event_loop_started) return ClockConnectorError.EventLoopAlreadyStarted;
        self.has_event_loop_started = true;

        var current_module = self.modules[0];

        while (is_active.*) {
            current_module.render(self);
            self.interface.clearScreen(self.interface.ctx);
            current_module = self.modules[std.crypto.random.intRangeAtMost(usize, 0, self.modules.len - 1)];
        }
    }
};
