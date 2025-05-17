const std = @import("std");
const renderer = @import("renderer.zig");
const common = @import("common");
const modules = @import("modules.zig");
const Connector = @import("./simConnector.zig").SimConnector;
const Clock = common.Clock;

fn start(clock: *Clock, logger: anytype, is_active: *bool) void {
    if (clock.*.startClock(is_active)) {} else |err| {
        logger.err("There was an error starting the clock: {}", .{err});
    }
}

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const logger = std.log.scoped(.Simulator);

    var tiles: [32][64]common.Color = undefined;

    for (0..32) |y| {
        for (0..64) |x| {
            tiles[y][x] = common.Color{ .r = 0, .g = 0, .b = 0 };
        }
    }

    var connector = Connector{
        .blank_tiles = tiles,
        .tile_pointer = &tiles,
    };

    var clock = Clock{ .interface = connector.connectorInterface(), .has_event_loop_started = false, .modules = &[_]common.module.ClockModule{ modules.test_module, modules.test_module2 } };

    var is_active: bool = true;

    if (std.Thread.spawn(.{}, start, .{ &clock, logger, &is_active })) |_| {
        logger.info("Started clock connector...", .{});
    } else |err| switch (err) {
        error.Unexpected => logger.err("There was an unexpected error with the clock thread!", .{}),
        else => |any_err| logger.err("There was an error with the clock thread: {}", .{@TypeOf(any_err)}),
    }

    if (renderer.startSimulator(logger, &tiles, &is_active)) {} else |err| {
        logger.err("There was an error with the simulator window: {}", .{err});
    }
}
