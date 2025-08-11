const std = @import("std");
const common = @import("common");
const Connector = @import("./hardwareConnector.zig").HardwareConnector;
const Clock = common.Clock;
const loadModuleFromLuau = common.luau.loader.loadModuleFromLuau;
const utils = common.connector_utils;

pub fn main() void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();
    const logger = std.log.scoped(.Hardware);

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

    if (common.font.FontStore.init(allocator)) {} else |err| {
        logger.err("Error loading fonts: {s}", .{@errorName(err)});
        std.process.exit(1);
    }

    var connector = Connector{};

    if (connector.init()) |_| {} else |_| {
        logger.err("There was an error initializing the hardware driver", .{});
    }
    defer connector.deinit();

    //Create list of module sources from filenames variable

    var modules = std.ArrayList(common.module.ClockModuleSource).init(allocator);
    defer modules.deinit();

    utils.loadModuleFiles(allocator, filenames, logger, &modules);

    var clock = Clock{
        .interface = connector.connectorInterface(),
        .has_event_loop_started = false,
        .modules = modules.items,
        .allocator = allocator,
    };

    var is_active: bool = true;

    if (std.Thread.spawn(.{}, utils.startClock, .{ &clock, logger, &is_active })) |_| {
        logger.info("Started clock connector...", .{});
    } else |e| {
        logger.err("There was an error with the clock thread: {s}", .{@errorName(e)});
        std.process.exit(1);
    }
}
