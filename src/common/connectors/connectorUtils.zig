const std = @import("std");
const common = @import("../common.zig");
const Clock = common.Clock;

///Starts the clock and handles errors
pub fn startClock(clock: *Clock, logger: anytype, is_active: *bool) void {
    if (clock.*.startClock(is_active)) {} else |err| {
        logger.err("There was an error starting the clock: {}", .{err});
    }
}

///Appends a list of module sources from filenames variable to given modules variable.
pub fn loadModuleFiles(allocator: std.mem.Allocator, filenames: []const u8, logger: anytype, modules: *std.ArrayList(common.module.ClockModuleSource)) void {
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
            return;
        };
    }
}
