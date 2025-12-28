const std = @import("std");
const zlua = @import("zlua");
const common = @import("../common.zig");
const Luau = zlua.Lua;

pub const logger = std.log.scoped(.luau_interpreter);

///Open Luau libraries for use in our sandbox.
///*(we don't want to open coroutines)*
inline fn openLuauStd(luau: *Luau) void {
    luau.openBase();
    luau.openMath();
    luau.openTable();
    luau.openString();
    luau.openBit32();
    luau.openUtf8();
    luau.openOS();
    luau.openDebug();
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
                logger.err("LuauTry caught: {t}. Expected type: {s}", .{ err, @typeName(T) });
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

const LuauError = error{
    OtherError,
    LuauError,
    FileNotFound,
    OutOfMemory,
};

///All of the possible errors that could occur when loading a clock module from Luau.
pub const ClockModuleError = error{
    DebugModule,
    ModuleParsingError,
} || LuauError;

///All of the errors that could occur when loading clock config from Luau.
pub const ClockConfigError = error{
    ConfigNotInitialized,
    ConfigParsingError,
    ConfigValidationError,
} || LuauError;

///Attempts to read the given luau module file and if it returns a Luau module builder converts the Luau table into a ClockModule.
///If the module does not return the Luau code will still be ran but this function will return a DebugModule error. This is useful for testing in Luau.
pub fn loadModuleFromLuau(module_file_name: []const u8, allocator: std.mem.Allocator, config_ptr: *std.StringHashMap([]const u8)) ClockModuleError!*common.module.ClockModule {
    // Interpret the file
    const full_module_file_name = std.fmt.allocPrint(allocator, "{s}.luau", .{module_file_name}) catch return error.OutOfMemory;
    defer allocator.free(full_module_file_name);

    const luau_file = common.connector_utils.readResource(allocator, full_module_file_name, .MODULE) catch |e| switch (e) {
        error.FileNotFound => return error.FileNotFound,
        inline else => {
            logger.err("Error reading module file: {s} -> {t}", .{ module_file_name, e });
            return error.OtherError;
        },
    };
    defer allocator.free(luau_file);

    var luau = zlua.Lua.init(allocator) catch return error.OtherError;

    openLuauStd(luau);

    //Load exports
    common.luau.exports.global.load_export(luau, config_ptr);
    common.luau.exports.time.load_export(luau);
    common.luau.exports.http.load_export(luau);
    common.luau.exports.json.load_export(luau);
    common.luau.exports.nice_clock.load_export(luau);

    const luau_bytecode = try zlua.compile(allocator, luau_file, .{});

    luau.loadBytecode("...", luau_bytecode) catch {
        const error_str = luau.toString(-1) catch "ERR";
        logger.err("{s}", .{error_str});
        return error.LuauError;
    };
    luau.protectedCall(.{ .results = 1 }) catch |e| {
        const error_str = luau.toString(-1) catch "ERR";
        logger.err("{s}", .{error_str});
        logger.err("{t}", .{e});
    };

    // Load module
    //
    //This is a mess because when we deinit the lua module it deallocates all the memory from luau therefore deallocating our module's fields.
    const return_type = luau.typeOf(1);
    if (return_type != zlua.LuaType.table and return_type != zlua.LuaType.nil) {
        logger.err("Invalid module return type: {s}", .{luau.typeName(return_type)});
        return error.OtherError;
    }
    if (return_type == zlua.LuaType.nil) return error.DebugModule;

    _ = luau.getField(1, "name");
    const module_name_field = luau.toString(-1) catch return error.ModuleParsingError;
    const module_name = try allocator.dupe(u8, module_name_field[0..module_name_field.len]);

    _ = luau.getField(1, "timelimit");
    const time_limit_field = luau.toInteger(-1) catch return error.ModuleParsingError;
    const time_limit = try allocator.create(u64);
    time_limit.* = @intCast(time_limit_field);

    _ = luau.getField(1, "imagenames");
    const image_names_field = luau.toAnyInternal([][]const u8, allocator, true, -1) catch return error.ModuleParsingError;
    var image_names = try allocator.dupe([]const u8, image_names_field);

    for (image_names_field, 0..) |image_name, i| {
        const new_image_name = try allocator.dupe(u8, image_name);
        image_names[i] = new_image_name;
    }

    var root_component: *common.components.RootComponent = undefined;

    if (common.luau.import_components.rootComponentFromLuau(luau, allocator)) |root| {
        root_component = root;
    } else |e| {
        logger.err("Error creating root component for module {s}; ({t})", .{ module_name, e });
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

///Used to store clock configuration data
///This struct is created in the main class and is used to run and parse config.luau returning the modules to load as well as the clock's brightness.
///This allows for the design of intelligent configs allowing for users to control which modules are loaded based on luau code.
pub const ClockConfig = struct {
    allocator: std.mem.Allocator,
    ///Owns key and value slices in `config`.
    config_map_allocator: *std.heap.ArenaAllocator,
    modules: *std.ArrayList(*common.module.ClockModuleSource),
    config: *std.StringHashMap([]const u8),

    initialized: bool = false,
    luau: *Luau = undefined,
    brightness: u8 = 100,

    ///**Requires `loadLuauConfigFile` to have been run before running this.**
    ///Takes the Luau instance created by loadLuauConfigFile and runs the `get_config` function and turns the returned `ClockConfig` table into values in the `ClockConfig` struct.
    pub fn updateClockConfig(self: *ClockConfig) ClockConfigError!void {
        if (!self.initialized) return error.ConfigNotInitialized;

        const luau = self.luau;

        const config_fn_type = luau.getGlobal("get_config") catch |e| {
            logger.err("There was an error getting the function 'get_config' from config.luau: {t}", .{e});
            return error.ConfigParsingError;
        };

        if (config_fn_type != .function) {
            logger.err("'get_config' in config.luau must be a function!", .{});
            return error.ConfigParsingError;
        }

        luau.protectedCall(.{ .results = 1 }) catch |e| {
            const error_str = luau.toString(-1) catch "ERR";
            logger.err("{s}", .{error_str});
            logger.err("{t}", .{e});
            return error.LuauError;
        };

        const return_type = luau.typeOf(1);
        if (return_type != zlua.LuaType.table) {
            logger.err("'get_config' must return a table, found: {s}", .{luau.typeName(return_type)});
            return error.ConfigParsingError;
        }

        _ = luau.getField(1, "brightness");
        const brightness_field = luau.toInteger(-1) catch {
            logger.err("`brightness` field not found in `get_config` return table!", .{});
            return error.ConfigParsingError;
        };

        if (brightness_field > 100 or brightness_field < 0) {
            logger.err("Clock brightness must be between 0 and 100 inclusive! Brightness set to: {d}.", .{brightness_field});
            return error.ConfigValidationError;
        }

        self.brightness = @intCast(brightness_field);

        _ = luau.getField(1, "modules");

        const modules_field = luau.toAnyInternal([][]const u8, self.allocator, true, -1) catch {
            logger.err("`modules` field not found in `get_config` return table!", .{});
            return error.ConfigParsingError;
        };

        defer self.allocator.free(modules_field);

        //We need to dupe this memory because once this function goes out of scope, all allocations made by Luau are deallocated.
        for (modules_field) |module_name| {
            const new_module_name = try self.allocator.dupe(u8, module_name);
            const new_module_source = try self.allocator.create(common.module.ClockModuleSource);
            new_module_source.* = .{ .custom = new_module_name };
            try self.modules.append(self.allocator, new_module_source);
        }
        luau.pop(1);

        const config_type = luau.getField(1, "config");
        if (config_type != .table) {
            logger.err("`config` field returned by `get_config` must be a table!", .{});
            return error.ConfigParsingError;
        }

        luau.pushNil();
        while (luau.next(-2)) {
            const key_index = luau.getTop() - 1;
            const val_index = luau.getTop();

            const key_type = luau.typeOf(key_index);
            const val_type = luau.typeOf(val_index);

            if (key_type != .string or (val_type != .string and val_type != .number)) {
                logger.err("There was a parsing issue with the 'config' table in config.luau. Ensure keys are strings and values are either strings or ints!", .{});
                return error.ConfigParsingError;
            }
            const key = luau.toString(key_index) catch |e| {
                logger.err("There was an error fetching a key from the config table in config.luau: {t}", .{e});
                return error.ConfigParsingError;
            };

            const val = luau.toString(val_index) catch |e| {
                logger.err("There was an error fetching a value from the config table in config.luau: {t}", .{e});
                return error.ConfigParsingError;
            };

            const new_key = try self.config_map_allocator.allocator().dupe(u8, key);
            const new_val = try self.config_map_allocator.allocator().dupe(u8, val);

            try self.config.put(new_key, new_val);
            luau.pop(1);
        }

        luau.pop(3);
    }

    ///Cleans out all **NON**-builtin modules from the list of module sources, freeing each item in the array.
    ///Also clears the config map.
    pub fn freeModules(self: *ClockConfig) void {
        for (self.modules.items) |item| {
            switch (item.*) {
                .custom => |c| self.allocator.free(c),
                else => {},
            }
            self.allocator.destroy(item);
        }
        self.modules.clearRetainingCapacity();
        self.config.clearRetainingCapacity();
        self.luau.gcCollect();
        if (!self.config_map_allocator.reset(.free_all)) logger.err("There was an error freeing the config map's memory!", .{});
    }

    ///Reads `{cwd}/config.luau` and compiles the Luau bytecode creates the `Luau` field in `ClockConfig`..
    ///**This only needs to be called once.**
    pub fn loadLuauConfigFile(self: *ClockConfig) LuauError!void {
        // Interpret the file
        const luau_file = common.connector_utils.readResource(self.allocator, "config.luau", .CWD) catch |e| switch (e) {
            error.FileNotFound => {
                logger.err("Could not find file: '{{cwd}}/config.luau!'", .{});
                return error.FileNotFound;
            },
            inline else => {
                logger.err("Error reading clock config file ({{cwd}}/config.luau) -> {t}", .{e});
                return error.OtherError;
            },
        };
        defer self.allocator.free(luau_file);

        var luau = zlua.Lua.init(self.allocator) catch return error.OtherError;
        self.luau = luau;

        openLuauStd(luau);
        common.luau.exports.global.load_export(luau, self.config);
        common.luau.exports.time.load_export(luau);
        common.luau.exports.http.load_export(luau);
        common.luau.exports.json.load_export(luau);

        const luau_bytecode = try zlua.compile(self.allocator, luau_file, .{});
        defer self.allocator.free(luau_bytecode);

        luau.loadBytecode("...", luau_bytecode) catch {
            const error_str = luau.toString(-1) catch "ERR";
            logger.err("{s}", .{error_str});
            return error.LuauError;
        };

        //Run the entire file first to initialize all variables.
        luau.protectedCall(.{}) catch |e| {
            const error_str = luau.toString(-1) catch "ERR";
            logger.err("{s}", .{error_str});
            logger.err("{t}", .{e});
            return error.LuauError;
        };

        self.initialized = true;
    }
};
