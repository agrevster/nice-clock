const std = @import("std");
const renderer = @import("renderer.zig");
const common = @import("common");
const Connector = @import("./simConnector.zig").SimConnector;
const Clock = common.Clock;

fn start(clock: *Clock, logger: anytype, is_active: *bool) void {
    if (clock.*.startClock(is_active)) {} else |err| {
        logger.err("There was an error starting the clock: {}", .{err});
    }
}

pub fn main() void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();
    const logger = std.log.scoped(.Simulator);

    var tiles: [32][64]common.Color = undefined;

    for (0..32) |y| {
        for (0..64) |x| {
            tiles[y][x] = common.Color{ .r = 0, .g = 0, .b = 0 };
        }
    }

    if (common.font.FontStore.init(allocator)) {} else |err| {
        logger.err("{s}", .{@errorName(err)});
    }

    var connector = Connector{
        .blank_tiles = tiles,
        .tile_pointer = &tiles,
    };

    var clock = Clock{
        .interface = connector.connectorInterface(),
        .has_event_loop_started = false,
        .modules = &[_]common.module.ClockModule{},
        .allocator = allocator,
    };

    var is_active: bool = true;

    if (std.Thread.spawn(.{}, start, .{ &clock, logger, &is_active })) |_| {
        logger.info("Started clock connector...", .{});
    } else |err| switch (err) {
        error.Unexpected => logger.err("There was an unexpected error with the clock thread!", .{}),
        else => |any_err| logger.err("There was an error with the clock thread: {s}", .{@errorName(any_err)}),
    }

    if (renderer.startSimulator(logger, &tiles, &is_active)) {} else |err| {
        logger.err("There was an error with the simulator window: {s}", .{@errorName(err)});
    }
}
