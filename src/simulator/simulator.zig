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
        logger.err("{s}", .{@errorName(err)});
        std.process.exit(1);
    }

    var connector = Connector{
        .blank_tiles = tiles,
        .tile_pointer = &tiles,
    };

    //Create list of module sources from filenames variable

    var modules = std.ArrayList(common.module.ClockModuleSource).init(allocator);

    var filenames_iterator = std.mem.splitSequence(u8, filenames, ",");

    while (filenames_iterator.next()) |filename| {
        //We have to make a copy of the string to append it because otherwise the loop will reuse the memory.
        const new_filename = allocator.dupe(u8, filename) catch |e| {
            logger.err("Error copying filename string for filename: {s}. {s}", .{ filename, @errorName(e) });
            return;
        };

        const new_source = allocator.create(common.module.ClockModuleSource) catch |e| {
            logger.err("Error creating module source for filename: {s}. {s}", .{ filename, @errorName(e) });
            return;
        };

        new_source.* = .{ .custom = new_filename };

        modules.append(new_source.*) catch |e| {
            logger.err("Error appending item: {s} to modules: {s}", .{ filename, @errorName(e) });
        };
    }

    var clock = Clock{
        .interface = connector.connectorInterface(),
        .has_event_loop_started = false,
        .modules = modules.items,
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
}
