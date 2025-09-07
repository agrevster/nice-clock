const std = @import("std");
const renderer = @import("renderer.zig");
const common = @import("common");
const Connector = @import("./simConnector.zig").SimConnector;
const Clock = common.Clock;
const loadModuleFromLuau = common.luau.loader.loadModuleFromLuau;
const utils = common.connector_utils;

pub fn main() void {
    var gpa = std.heap.DebugAllocator(.{ .thread_safe = false }).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args_arena = std.heap.ArenaAllocator.init(allocator);
    const args_allocator = args_arena.allocator();
    defer args_arena.deinit();
    const logger = std.log.scoped(.Simulator);

    //Allow for passing module file name via command line arguments
    const args = std.process.argsAlloc(args_allocator) catch |e| {
        logger.err("Error allocating arguments for simulator: {s}", .{@errorName(e)});
        std.process.exit(1);
    };

    var filenames: []const u8 = undefined;

    if (args.len > 1) {
        filenames = args[1][0..];
    } else {
        filenames = "test";
    }

    var tiles: [32][64]common.Color = undefined;

    for (0..32) |y| {
        for (0..64) |x| {
            tiles[y][x] = common.Color{ .r = 0, .g = 0, .b = 0 };
        }
    }

    if (common.font.FontStore.init(allocator)) {} else |err| {
        logger.err("Error loading fonts: {s}", .{@errorName(err)});
        std.process.exit(1);
    }
    defer common.font.FontStore.deinit(allocator);

    var connector = Connector{
        .blank_tiles = tiles,
        .tile_pointer = &tiles,
    };

    var modules = std.ArrayList(*common.module.ClockModuleSource).empty;
    utils.loadModuleFiles(allocator, filenames, logger, &modules);
    defer utils.unloadModuleFiles(allocator, &modules);

    var clock = Clock{
        .interface = connector.connectorInterface(),
        .has_event_loop_started = false,
        .modules = modules.items,
        .allocator = allocator,
    };

    var is_active = std.atomic.Value(bool).init(true);

    if (std.Thread.spawn(.{}, utils.startClock, .{ &clock, logger, &is_active })) |t| {
        logger.info("Started clock connector...", .{});
        if (renderer.startSimulator(logger, &tiles, &is_active)) {} else |err| {
            logger.err("There was an error with the simulator window: {s}", .{@errorName(err)});
            std.process.exit(1);
        }
        t.detach();
    } else |e| {
        logger.err("There was an error with the clock thread: {s}", .{@errorName(e)});
        std.process.exit(1);
    }
}
