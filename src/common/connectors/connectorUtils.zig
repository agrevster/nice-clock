const std = @import("std");
const common = @import("../common.zig");
const Clock = common.Clock;

///Starts the clock and handles errors
pub fn startClock(clock: *Clock, logger: anytype, is_active: *std.atomic.Value(bool)) void {
    if (clock.*.startClock(is_active)) {} else |err| {
        logger.err("There was an error starting the clock: {}", .{err});
    }
}

///Appends a list of module sources from filenames variable to given modules variable.
pub fn loadModuleFiles(allocator: std.mem.Allocator, filenames: []const u8, logger: anytype, modules: *std.ArrayList(*common.module.ClockModuleSource)) void {
    var filenames_iterator = std.mem.splitSequence(u8, filenames, ",");

    while (filenames_iterator.next()) |filename| {
        //We have to make a copy of the string to append it because otherwise the loop will reuse the memory.
        const new_filename = allocator.dupe(u8, filename) catch |e| {
            logger.err("Error copying filename string for filename: {s}. {t}", .{ filename, e });
            return;
        };

        const new_source = allocator.create(common.module.ClockModuleSource) catch |e| {
            logger.err("Error creating module source for filename: {s}. {t}", .{ filename, e });
            return;
        };

        new_source.* = .{ .custom = new_filename };

        modules.append(allocator, new_source) catch |e| {
            logger.err("Error appending item: {s} to modules: {t}", .{ filename, e });
            return;
        };
    }
}

///Cleans out all **NON**-builtin modules from the list of module sources, freeing each item in the array.
pub fn unloadModuleFiles(allocator: std.mem.Allocator, modules: *std.ArrayList(*common.module.ClockModuleSource)) void {
    for (modules.items) |item| {
        switch (item.*) {
            .custom => |c| allocator.free(c),
            else => {},
        }
        allocator.destroy(item);
    }
    modules.deinit(allocator);
}

///Used to specify the type of resource to read.
///MODULE -> anything inside cwd/modules
///ASSET -> anything inside cwd/assets
pub const ResourceType = enum { MODULE, ASSET };

pub fn readResource(allocator: std.mem.Allocator, path: []const u8, resource_type: ResourceType) ![]const u8 {
    var cwd = std.fs.cwd();
    var resource_dir = switch (resource_type) {
        .ASSET => try cwd.openDir("assets", .{}),
        .MODULE => try cwd.openDir("modules", .{}),
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
