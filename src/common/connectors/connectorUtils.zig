const std = @import("std");
const common = @import("../common.zig");
const Clock = common.Clock;

///Starts the clock and handles errors
pub fn startClock(clock: *Clock, logger: anytype, is_active: *std.atomic.Value(bool)) void {
    if (clock.*.startClock(is_active)) {} else |err| {
        logger.err("There was an error starting the clock: {}", .{err});
        std.process.exit(1);
    }
}

///Used to specify the type of resource to read.
///MODULE -> anything inside cwd/modules
///ASSET -> anything inside cwd/assets
///CWD -> anything inside cwd
pub const ResourceType = enum { MODULE, ASSET, CWD };

///Reads a given file returning the caller **owned** contents of the file. The file is located in the given `resource_type`'s directory.
pub fn readResource(allocator: std.mem.Allocator, path: []const u8, resource_type: ResourceType) ![]const u8 {
    var cwd = std.fs.cwd();
    var resource_dir = switch (resource_type) {
        .ASSET => try cwd.openDir("assets", .{}),
        .MODULE => try cwd.openDir("modules", .{}),
        .CWD => try cwd.openDir(".", .{}),
    };
    defer resource_dir.close();

    const resource_path = try resource_dir.realpathAlloc(allocator, ".");
    defer allocator.free(resource_path);
    const file_path = try resource_dir.realpathAlloc(allocator, path);
    defer allocator.free(file_path);

    if (!std.mem.startsWith(u8, file_path, resource_path)) return error.FileOutsideResourcePath;

    const file = try resource_dir.openFile(file_path, .{});
    defer file.close();

    const contents = try file.readToEndAlloc(allocator, 1_000_000);
    return contents;
}
