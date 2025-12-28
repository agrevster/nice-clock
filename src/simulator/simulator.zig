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

    const logger = std.log.scoped(.Simulator);

    var tiles: [32][64]common.Color = undefined;

    inline for (0..32) |y| {
        for (0..64) |x| {
            tiles[y][x] = common.Color{ .r = 0, .g = 0, .b = 0 };
        }
    }

    if (common.font.FontStore.init(allocator)) {} else |err| {
        logger.err("Error loading fonts: {t}", .{err});
        std.process.exit(1);
    }
    defer common.font.FontStore.deinit(allocator);

    var connector = Connector{
        .blank_tiles = tiles,
        .tile_pointer = &tiles,
    };

    var modules = std.ArrayList(*common.module.ClockModuleSource).empty;
    defer modules.deinit(allocator);

    var config_map = std.StringHashMap([]const u8).init(allocator);
    defer config_map.deinit();

    var config_item_allocator = std.heap.ArenaAllocator.init(allocator);
    defer config_item_allocator.deinit();

    var config = common.luau.loader.ClockConfig{
        .allocator = allocator,
        .config = &config_map,
        .config_map_allocator = &config_item_allocator,
        .modules = &modules,
    };

    config.loadLuauConfigFile() catch |e| {
        logger.err("There was an error loading the clock's config file: {t}", .{e});
        std.process.exit(1);
    };

    defer config.luau.deinit();
    defer config.freeModules();

    var clock = Clock{
        .interface = connector.connectorInterface(),
        .has_event_loop_started = false,
        .allocator = allocator,
        .config = &config,
    };

    var is_active = std.atomic.Value(bool).init(true);

    if (std.Thread.spawn(.{}, utils.startClock, .{ &clock, logger, &is_active })) |t| {
        logger.info("Started clock connector...", .{});
        if (renderer.startSimulator(logger, &tiles, &is_active)) {} else |err| {
            logger.err("There was an error with the simulator window: {t}", .{err});
            std.process.exit(1);
        }
        t.detach();
    } else |e| {
        logger.err("There was an error with the clock thread: {t}", .{e});
        std.process.exit(1);
    }
}
