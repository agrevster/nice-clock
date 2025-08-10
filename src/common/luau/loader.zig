const std = @import("std");
const zlua = @import("zlua");
const common = @import("../common.zig");
const Luau = zlua.Lua;

pub const logger = std.log.scoped(.luau_interpreter);

///Reads a luau file located in _(cwd)/modules/_.
fn readModuleFile(file: []const u8, allocator: std.mem.Allocator) error{ OutOfMemory, FileNotFound, OtherError }![]const u8 {
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

///Used to help with error handling when working with Luau.
/// T should be the expected return type without error union.
/// Use unwrap to run the check.
/// If T contains an error raises a luau error with the given message and logs the error in Zig.
pub fn LuauTry(comptime T: type, error_message: []const u8) type {
    return struct {
        pub fn unwrap(luau: *zlua.Lua, item: anyerror!T) T {
            if (item) |item_no_err| {
                return item_no_err;
            } else |err| {
                logger.err("LuauTry caught: {s}. Expected type: {s}", .{ @errorName(err), @typeName(T) });
                luauError(luau, error_message);
            }
        }
    };
}

///Raises a luau error and prevents the Zig program from continuing.
pub fn luauError(luau: *Luau, message: []const u8) noreturn {
    _ = luau.pushString(message);
    luau.raiseError();
}

///All of the possible errors that could occur when loading a clock module from Luau.
pub const Error = error{
    OtherError,
    LuauError,
    FileNotFound,
    DebugModule,
    ModuleParsingError,
};

///Attempts to read the given luau module file and if it returns a Luau module builder converts the Luau table into a ClockModule.
///If the module does not return the Luau code will still be ran but this function will return a DebugModule error. This is useful for testing in Luau.
pub fn loadModuleFromLuau(module_file_name: []const u8, allocator: std.mem.Allocator) Error!*common.module.ClockModule {
    // Interpret the file
    const luau_file = readModuleFile(module_file_name, allocator) catch |e| {
        logger.err("{s}", .{@errorName(e)});
        return Error.OtherError;
    };
    defer allocator.free(luau_file);

    var luau = zlua.Lua.init(allocator) catch return Error.OtherError;
    defer luau.deinit();

    //Open libraries (we don't want to open coroutines)
    luau.openBase();
    luau.openMath();
    luau.openTable();
    luau.openString();
    luau.openBit32();
    luau.openUtf8();
    luau.openOS();
    luau.openDebug();

    //Load exports
    common.luau.exports.global.load_export(luau);
    common.luau.exports.time.load_export(luau);
    common.luau.exports.nice_clock.load_export(luau);
    common.luau.exports.http.load_export(luau);

    const luau_bytecode = zlua.compile(allocator, luau_file, .{}) catch |e| switch (e) {
        error.OutOfMemory => return Error.OtherError,
    };
    defer allocator.free(luau_bytecode);

    luau.loadBytecode("...", luau_bytecode) catch {
        const error_str = luau.toString(-1) catch "ERR";
        logger.err("{s}", .{error_str});
        return Error.LuauError;
    };
    luau.protectedCall(.{ .results = 1 }) catch |e| {
        const error_str = luau.toString(-1) catch "ERR";
        logger.err("{s}", .{error_str});
        logger.err("{s}", .{@errorName(e)});
    };

    // Load module
    //
    //This is a mess because when we deinit the lua module it deallocates all the memory from luau therefore deallocating our module's fields.
    const return_type = luau.typeOf(1);
    if (return_type != zlua.LuaType.table and return_type != zlua.LuaType.nil) {
        logger.err("Invalid module return type: {s}", .{luau.typeName(return_type)});
        return Error.OtherError;
    }
    if (return_type == zlua.LuaType.nil) return Error.DebugModule;

    _ = luau.getField(1, "name");
    const module_name_field = luau.toString(-1) catch return Error.ModuleParsingError;
    const module_name = allocator.dupe(u8, module_name_field[0..module_name_field.len]) catch |e| {
        logger.err("Memory error: {s}", .{@errorName(e)});
        return Error.OtherError;
    };

    _ = luau.getField(1, "timelimit");
    const time_limit_field = luau.toInteger(-1) catch return Error.ModuleParsingError;
    const time_limit = allocator.create(u64) catch |e| {
        logger.err("Memory error: {s}", .{@errorName(e)});
        return Error.OtherError;
    };
    time_limit.* = @intCast(time_limit_field);

    _ = luau.getField(1, "imagenames");
    const image_names_field = luau.toAnyInternal([][]const u8, allocator, true, -1) catch return Error.ModuleParsingError;
    var image_names = allocator.dupe([]const u8, image_names_field) catch |e| {
        logger.err("Memory error: {s}", .{@errorName(e)});
        return Error.OtherError;
    };
    for (image_names_field, 0..) |image_name, i| {
        const new_image_name = allocator.dupe(u8, image_name) catch |e| {
            logger.err("Memory error: {s}", .{@errorName(e)});
            return Error.OtherError;
        };
        image_names[i] = new_image_name;
    }

    var root_component: *common.components.RootComponent = undefined;

    if (common.luau.import_components.rootComponentFromLuau(luau, allocator)) |root| {
        root_component = root;
    } else |e| {
        logger.err("Error creating root component for module {s}; ({s})", .{ module_name, @errorName(e) });
        return error.ModuleParsingError;
    }

    const mod = allocator.create(common.module.ClockModule) catch {
        logger.err("Error allocating clock module!", .{});
        return error.OtherError;
    };

    mod.* = common.module.ClockModule{
        .name = module_name,
        .time_limit_s = time_limit.*,
        .image_names = image_names,
        .root_component = root_component.*,
    };
    return mod;
}
