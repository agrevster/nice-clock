const std = @import("std");
const zlua = @import("zlua");
const common = @import("../common.zig");

const Error = error{ MemoryError, LuauError, FileNotFound };

pub const logger = std.log.scoped(.luau_interpreter);

fn load_module_file(file: []const u8, allocator: std.mem.Allocator) error{ OutOfMemory, FileNotFound, OtherError }![]const u8 {
    const file_name = std.fmt.allocPrint(allocator, "./modules/{s}.luau", .{file}) catch return error.OutOfMemory;
    defer allocator.free(file_name);
    const file_contents = std.fs.cwd().readFileAlloc(allocator, file_name, 1000000) catch |e| switch (e) {
        error.FileNotFound => return error.FileNotFound,
        inline else => {
            logger.err("Error loading text from module file: {s} -> {s}", .{ file_name, @errorName(e) });
            return error.OtherError;
        },
    };
    return file_contents;
}

pub fn LuauTry(comptime T: type, error_message: []const u8) type {
    return struct {
        pub fn unwrap(luau: *zlua.Lua, item: anyerror!T) T {
            if (item) |item_no_err| {
                return item_no_err;
            } else |err| {
                logger.err("LuauTry caught: {s}. Expected type: {s}", .{ @errorName(err), @typeName(T) });
                _ = luau.pushString(error_message);
                luau.raiseError();
            }
        }
    };
}

pub fn interpret(module_file_name: []const u8, allocator: std.mem.Allocator) Error!void {
    const luau_file = load_module_file(module_file_name, allocator) catch |e| switch (e) {
        error.OtherError => return Error.MemoryError,
        inline else => {
            logger.err("{s}", .{@errorName(e)});
            return Error.MemoryError;
        },
    };
    defer allocator.free(luau_file);

    var lua = zlua.Lua.init(allocator) catch return Error.MemoryError;
    defer lua.deinit();

    //Open libraries (we don't want to open coroutines)
    lua.openBase();
    lua.openMath();
    lua.openTable();
    lua.openString();
    lua.openBit32();
    lua.openUtf8();
    lua.openOS();
    lua.openDebug();

    //Load exports
    common.luau.exports.global.load_export(lua);
    common.luau.exports.time.load_export(lua);

    const luau_bytecode = zlua.compile(allocator, luau_file, .{}) catch |e| switch (e) {
        error.OutOfMemory => return Error.MemoryError,
    };
    defer allocator.free(luau_bytecode);

    lua.loadBytecode("...", luau_bytecode) catch {
        const error_str = lua.toString(-1) catch "ERR";
        logger.err("{s}", .{error_str});
        return Error.LuauError;
    };
    lua.protectedCall(.{}) catch |e| {
        const error_str = lua.toString(-1) catch "ERR";
        logger.err("{s}", .{error_str});
        logger.err("{s}", .{@errorName(e)});
    };
}

test {
    const allocator = std.testing.allocator;

    interpret("test", allocator) catch |e| {
        logger.err("{s}", .{@errorName(e)});
    };
}
