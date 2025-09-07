const std = @import("std");
const common = @import("common");
const Connector = @import("./hardwareConnector.zig").HardwareConnector;
const Clock = common.Clock;
const loadModuleFromLuau = common.luau.loader.loadModuleFromLuau;
const utils = common.connector_utils;

pub fn main() void {
    const logger = std.log.scoped(.Hardware);
    var gpa = std.heap.DebugAllocator(.{ .thread_safe = false }).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    //Allow for passing module file name via command line arguments
    var args_arena = std.heap.ArenaAllocator.init(allocator);
    const args_allocator = args_arena.allocator();
    defer args_arena.deinit();
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

    if (common.font.FontStore.init(allocator)) {} else |err| {
        logger.err("Error loading fonts: {s}", .{@errorName(err)});
        std.process.exit(1);
    }

    defer common.font.FontStore.deinit(allocator);

    var connector = Connector{};

    if (connector.init()) |_| {} else |_| {
        logger.err("There was an error initializing the hardware driver", .{});
    }
    defer connector.deinit();

    //Create list of module sources from filenames variable

    var modules = std.ArrayList(*common.module.ClockModuleSource).empty;
    defer modules.deinit(allocator);

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
        t.join();
    } else |e| {
        logger.err("There was an error with the clock thread: {s}", .{@errorName(e)});
        std.process.exit(1);
    }
}
