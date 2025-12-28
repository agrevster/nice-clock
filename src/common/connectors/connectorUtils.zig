const std = @import("std");
const common = @import("../common.zig");
const zlua = @import("zlua");
const Clock = common.Clock;
const Luau = zlua.Lua;

///Starts the clock and handles errors
pub fn startClock(clock: *Clock, logger: anytype, is_active: *std.atomic.Value(bool)) void {
    if (clock.*.startClock(is_active)) {} else |err| {
        logger.err("There was an error starting the clock: {t}", .{err});
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

///A debug function used to print out the Luau stack.
pub fn printLuauStack(luau: *Luau) !void {
    const top = luau.getTop();

    std.debug.print("Lua stack (top = {d}):\n", .{top});

    var i: c_int = 1;
    while (i <= top) : (i += 1) {
        const t = luau.typeOf(i);
        const typeName = luau.typeName(t);

        std.debug.print("  [{d} / {d}] {s} = ", .{
            i, // positive index
            i - top - 1, // negative index
            typeName,
        });

        switch (t) {
            zlua.LuaType.number => {
                const n = try luau.toNumber(i);
                std.debug.print("{d}\n", .{n});
            },
            zlua.LuaType.string => {
                const s = try luau.toString(i);
                std.debug.print("'{s}'\n", .{s});
            },
            zlua.LuaType.boolean => {
                const b = luau.toBoolean(i);
                std.debug.print("{s}\n", .{if (b) "true" else "false"});
            },
            zlua.LuaType.nil => {
                std.debug.print("nil\n", .{});
            },
            else => {
                const ptr = try luau.toPointer(i);
                std.debug.print("({s}) {any}\n", .{ typeName, ptr });
            },
        }
    }
}
