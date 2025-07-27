const std = @import("std");
const zlua = @import("zlua");
const common = @import("../../common.zig");
const Luau = zlua.Lua;
const wrap = zlua.wrap;
const LuauTry = common.luau.loader.LuauTry;
const LuauArg = common.luau.import_components.LuauArg;
const luau_error = common.luau.loader.luau_error;
const generateLuauComponentBuilderFunctions = common.luau.import_components.generateLuauComponentBuilderFunctions;
const generateLuauFontFields = common.luau.import_components.generateLuauFontFields;

///Sends the exported functions to luau.
pub fn load_export(luau: *Luau) void {
    luau.newTable();

    luau.pushFunction(wrap(moduleBuilder));
    luau.setField(-2, "modulebuilder");
    generateLuauFontFields(luau);

    luau.setGlobal("niceclock");
}

// Helpers

// Luau trys for standard error message formats.
const tryPushImagenames = LuauTry(void, "Failed to push imagenames table.");
const tryPushComponents = LuauTry(void, "Failed to push components table.");
const tryParseBuilderStruct = LuauTry(ModuleBuilderTable, "Failed to parse builder struct from luau table.");
const tryGetIntFromTable = LuauTry(zlua.Integer, "Failed to get int from table.");
const tryGetBoolFromTable = LuauTry(bool, "Failed to get bool from table.");

const ModuleBuilderTable = struct {
    name: []const u8,
    timelimit: u32,
    imagenames: [][]const u8,
    components: []ClockComponentTable,

    /// Pushes a module builder struct onto the stack with a copy of init_fn and deinit_fn from the given builder_table_index
    fn pushSelf(self: ModuleBuilderTable, luau: *Luau, builder_table_index: i32) void {
        luau.newTable();
        _ = luau.pushString(self.name);
        luau.setField(-2, "name");
        luau.pushInteger(@intCast(self.timelimit));
        luau.setField(-2, "timelimit");
        tryPushImagenames.unwrap(luau, luau.pushAny(self.imagenames));
        luau.setField(-2, "imagenames");
        tryPushComponents.unwrap(luau, luau.pushAny(self.components));
        luau.setField(-2, "components");

        //Push copy of init_fn and deinit_fn
        const init_fn_type = luau.getField(builder_table_index, "init_fn");
        if (init_fn_type != zlua.LuaType.function and init_fn_type != zlua.LuaType.nil) luau_error(luau, "Invalid init fn type...");
        luau.setField(-2, "init_fn");
        const deinit_fn_type = luau.getField(builder_table_index, "deinit_fn");
        if (deinit_fn_type != zlua.LuaType.function and deinit_fn_type != zlua.LuaType.nil) luau_error(luau, "Invalid deinit fn type...");
        luau.setField(-2, "deinit_fn");

        pushFunctions(luau, -2);
    }

    fn pushFunctions(luau: *Luau, index: i32) void {
        luau.pushFunction(wrap(build_fn));
        luau.setField(index, "build");
        luau.pushFunction(wrap(set_init_fn));
        luau.setField(index, "init");
        luau.pushFunction(wrap(set_deinit_fn));
        luau.setField(index, "deinit");
        generateLuauComponentBuilderFunctions(luau);
    }
};

pub const ClockComponentTable = struct { number: u8, props: []common.luau.import_components.LuauArg };

pub const AnimationTable = struct { duration: u32, loop: bool, speed: i16 };

fn createModuleBuilderLuauTable(luau: *Luau, module_name: [:0]const u8, module_time: zlua.Integer, image_names: [][:0]const u8) void {
    luau.newTable();

    _ = luau.pushString(module_name);
    luau.setField(-2, "name");

    luau.pushInteger(module_time);
    luau.setField(-2, "timelimit");

    luau.newTable();
    for (image_names, 1..) |image_name, index| {
        const i: i32 = @intCast(index);
        _ = luau.pushString(image_name);
        luau.rawSetIndex(-2, i);
    }
    luau.setField(-2, "imagenames");

    luau.newTable();
    luau.setField(-2, "components");

    luau.pushNil();
    luau.setField(-2, "init_fn");
    luau.pushNil();
    luau.setField(-2, "deinit_fn");

    ModuleBuilderTable.pushFunctions(luau, -2);
}

// Functions

fn moduleBuilder(luau: *Luau) i32 {
    luau.checkType(1, zlua.LuaType.string);
    luau.checkType(2, zlua.LuaType.number);
    luau.checkType(3, zlua.LuaType.table);

    const module_name = LuauTry([:0]const u8, "Failed to parse name string.").unwrap(luau, luau.toString(1));
    const time_limit = LuauTry(zlua.Integer, "Failed to parse time limit integer.").unwrap(luau, luau.toInteger(2));
    var image_names: [][:0]const u8 = undefined;

    const string_list_len: usize = @intCast(@max(0, luau.objectLen(3)));
    image_names = luau.allocator().alloc([:0]const u8, string_list_len) catch luau_error(luau, "Error allocating image_names.");
    errdefer luau.allocator().free(image_names);

    const get_string_from_list = LuauTry([:0]const u8, "Failed to parse string from image names list.");

    for (1..string_list_len + 1) |i| {
        const index: i32 = @intCast(i);
        const t = luau.rawGetIndex(3, index);
        if (t != zlua.LuaType.string) luau_error(luau, "Expected list of type string.");
        image_names[i - 1] = get_string_from_list.unwrap(luau, luau.toString(-1));

        luau.pop(1);
    }

    createModuleBuilderLuauTable(luau, module_name, time_limit, image_names);

    return 1;
}

fn build_fn(luau: *Luau) i32 {
    luau.checkType(1, zlua.LuaType.table);

    const builder_table = tryParseBuilderStruct.unwrap(luau, luau.toStruct(ModuleBuilderTable, luau.allocator(), true, 1));

    luau.newTable();

    const init_fn_type = luau.getField(1, "init_fn");
    if (init_fn_type != zlua.LuaType.function and init_fn_type != zlua.LuaType.nil) luau_error(luau, "Invalid init fn type...");
    luau.setField(-2, "init");
    const deinit_fn_type = luau.getField(1, "deinit_fn");
    if (deinit_fn_type != zlua.LuaType.function and deinit_fn_type != zlua.LuaType.nil) luau_error(luau, "Invalid deinit fn type...");
    luau.setField(-2, "deinit");

    _ = luau.pushString(builder_table.name);
    luau.setField(-2, "name");
    luau.pushInteger(@intCast(builder_table.timelimit));
    luau.setField(-2, "timelimit");

    tryPushImagenames.unwrap(luau, luau.pushAny(builder_table.imagenames));
    luau.setField(-2, "imagenames");

    tryPushComponents.unwrap(luau, luau.pushAny(builder_table.components));
    luau.setField(-2, "components");

    return 1;
}

fn set_init_fn(luau: *Luau) i32 {
    luau.checkType(1, zlua.LuaType.table);
    luau.checkType(2, zlua.LuaType.function);

    const builder_table = tryParseBuilderStruct.unwrap(luau, luau.toStruct(ModuleBuilderTable, luau.allocator(), true, 1));

    luau.pushValue(2);
    luau.setField(1, "init_fn");
    builder_table.pushSelf(luau, 1);
    return 1;
}

fn set_deinit_fn(luau: *Luau) i32 {
    luau.checkType(1, zlua.LuaType.table);
    luau.checkType(2, zlua.LuaType.function);

    const builder_table = tryParseBuilderStruct.unwrap(luau, luau.toStruct(ModuleBuilderTable, luau.allocator(), true, 1));

    luau.pushValue(2);
    luau.setField(1, "deinit_fn");
    builder_table.pushSelf(luau, 1);
    return 1;
}

pub fn component_fn(luau: *Luau) i32 {
    luau.checkType(1, .table);

    const top: usize = @intCast(luau.getTop());
    var args = luau.allocator().alloc(LuauArg, top - 1) catch luau_error(luau, "Failed to allocate memory for arg list.");

    const component_id = luau.toInteger(Luau.upvalueIndex(1)) catch luau_error(luau, "Failed to get component_id from closure.");

    const Number = zlua.LuaType.number;
    const Nil = zlua.LuaType.nil;
    const Boolean = zlua.LuaType.boolean;
    //Validate arguments (we start at 1 because luau is weird)
    for (2..top + 1) |index| {
        const i: i32 = @intCast(index);
        switch (luau.typeOf(i)) {
            //We have to subtract one because Zig arrays start at 0 like a real language
            .boolean => args[index - 2] = LuauArg{ .bool = luau.toBoolean(i) },
            .string => args[index - 2] = LuauArg{ .string = luau.toString(i) catch "Error" },
            .number => args[index - 2] = LuauArg{ .int = tryGetIntFromTable.unwrap(luau, luau.toInteger(i)) },
            .table => {
                const r = luau.getField(i, "r");
                const g = luau.getField(i, "g");
                const b = luau.getField(i, "b");

                const x = luau.getField(i, "x");
                const y = luau.getField(i, "y");

                const duration = luau.getField(i, "duration");
                const loop = luau.getField(i, "loop");
                const speed = luau.getField(i, "speed");
                luau.pop(8);

                if ((r != Number or g != Number or b != Number) and (x != Number or y != Number) and (duration != Number or loop != Boolean or speed != Number)) luau_error(luau, "Table should be a Color, Position or Animation.");

                // RGB struct
                if ((r == Number and g == Number and b == Number) and (x == Nil and y == Nil) and (duration == Nil and loop == Nil and speed == Nil)) {
                    _ = luau.getField(i, "r");
                    _ = luau.getField(i, "g");
                    _ = luau.getField(i, "b");
                    args[index - 2] = LuauArg{ .color = .{
                        .r = @intCast(@min(255, @max(0, tryGetIntFromTable.unwrap(luau, luau.toInteger(-3))))),
                        .g = @intCast(@min(255, @max(0, tryGetIntFromTable.unwrap(luau, luau.toInteger(-2))))),
                        .b = @intCast(@min(255, @max(0, tryGetIntFromTable.unwrap(luau, luau.toInteger(-1))))),
                    } };
                    luau.pop(3);
                    continue;
                }

                if ((r == Nil and g == Nil and b == Nil) and (x == Number and y == Number) and (duration == Nil and loop == Nil and speed == Nil)) {
                    _ = luau.getField(i, "x");
                    _ = luau.getField(i, "y");
                    args[index - 2] = LuauArg{ .pos = .{
                        .x = @intCast(@min(255, @max(0, tryGetIntFromTable.unwrap(luau, luau.toInteger(-2))))),
                        .y = @intCast(@min(255, @max(0, tryGetIntFromTable.unwrap(luau, luau.toInteger(-1))))),
                    } };
                    luau.pop(2);
                    continue;
                }

                if ((r == Nil and g == Nil and b == Nil) and (x == Nil and y == Nil) and (duration == Number and loop == Boolean and speed == Number)) {
                    _ = luau.getField(i, "duration");
                    _ = luau.getField(i, "loop");
                    _ = luau.getField(i, "speed");
                    args[index - 2] = LuauArg{ .animation = .{
                        .duration = @intCast(@min(4294967296, @max(0, tryGetIntFromTable.unwrap(luau, luau.toInteger(-3))))),
                        .loop = tryGetBoolFromTable.unwrap(luau, luau.toBoolean(-2)),
                        .speed = @intCast(@min(32767, @max(-32767, tryGetIntFromTable.unwrap(luau, luau.toInteger(-1))))),
                    } };
                    luau.pop(3);
                    continue;
                }

                //Error to prevent mixing and matching...
                luau_error(luau, "Table should be a Color, Position or Animation.");
            },
            else => {
                luau_error(luau, "Invalid argument type!");
            },
        }
    }

    // Push the table with the added component in the components array.
    var builder_table = tryParseBuilderStruct.unwrap(luau, luau.toStruct(ModuleBuilderTable, luau.allocator(), true, 1));

    var new_components = luau.allocator().alloc(ClockComponentTable, builder_table.components.len + 1) catch {
        luau_error(luau, "Error appending to the component table.");
    };

    const clock_compoent = luau.allocator().create(ClockComponentTable) catch {
        luau_error(luau, "Error creating module builder table.");
    };

    std.mem.copyBackwards(ClockComponentTable, new_components, builder_table.components);

    clock_compoent.*.number = @intCast(component_id);
    clock_compoent.*.props = args;
    new_components[new_components.len - 1] = clock_compoent.*;
    builder_table.components = new_components;

    builder_table.pushSelf(luau, 1);
    return 1;
}
