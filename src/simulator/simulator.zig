const std = @import("std");
const renderer = @import("renderer.zig");
const common = @import("common");
const Connector = @import("./simConnector.zig").SimConnector;
const Clock = common.Clock;
const loadModuleFromLuau = common.luau.loader.loadModuleFromLuau;

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

    //Allow for passing module file name via command line arguments
    const args = std.process.argsAlloc(allocator) catch |e| {
        logger.err("Error allocating arguments for simulator: {s}", .{@errorName(e)});
        std.process.exit(1);
    };

    var filename: *const []const u8 = undefined;

    if (args.len > 1) {
        filename = &args[1][0..];
    } else {
        filename = &"test";
    }

    var tiles: [32][64]common.Color = undefined;

    for (0..32) |y| {
        for (0..64) |x| {
            tiles[y][x] = common.Color{ .r = 0, .g = 0, .b = 0 };
        }
    }

    if (common.font.FontStore.init(allocator)) {} else |err| {
        logger.err("{s}", .{@errorName(err)});
        std.process.exit(1);
    }

    var connector = Connector{
        .blank_tiles = tiles,
        .tile_pointer = &tiles,
    };

    if (loadModuleFromLuau(filename.*, allocator)) |test_module| {
        var module_array = [_]common.module.ClockModule{test_module.*};
        var clock = Clock{
            .interface = connector.connectorInterface(),
            .has_event_loop_started = false,
            .modules = &module_array,
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
            std.process.exit(1);
        }
    } else |e| {
        logger.err("Error loading file: {s}.luau from Luau: {s}", .{ filename.*, @errorName(e) });
    }
}
