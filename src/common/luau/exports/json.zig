const std = @import("std");
const zlua = @import("zlua");
const common = @import("../../common.zig");
const Luau = zlua.Lua;
const wrap = zlua.wrap;
const LuauTry = common.luau.loader.LuauTry;
const luauError = common.luau.loader.luauError;
const json = std.json;

///Sends the exported functions to luau.
pub fn load_export(luau: *Luau) void {
    luau.newTable();
    luau.pushFunction(wrap(load_fn));
    luau.setField(-2, "load");
    luau.pushFunction(wrap(dump_fn));
    luau.setField(-2, "dump");
    luau.setGlobal("json");
}

//WARNING: Due to the way luau handles null (nil) values, they will be ignored by clock JSON methods.

const logger = std.log.scoped(.luau_json);
fn parseToLuau(luau: *Luau, value: json.Value) void {
    switch (value) {
        //Basic types
        .null => _ = luau.pushNil(),
        .string => |v| _ = luau.pushString(v),
        .integer => |v| luau.pushInteger(@truncate(v)),
        .float => |v| luau.pushNumber(v),
        .bool => |v| luau.pushBoolean(v),
        .number_string => |v| _ = luau.pushString(v),
        //Recursive types (on my)
        .object => |v| {
            luau.newTable();
            for (v.keys()) |key| {
                const val = v.get(key) orelse json.Value{ .string = "" };
                parseToLuau(luau, val);

                //Uggg fine! I guess I'll terminate the string
                const key_sentinel = luau.allocator().allocSentinel(u8, key.len, '\x00') catch luauError(luau, "Failed to allocate sentinel string for key");
                std.mem.copyForwards(u8, key_sentinel, key);

                luau.setField(-2, key_sentinel);
            }
        },
        .array => |v| {
            luau.newTable();
            for (v.items, 1..) |item, i| {
                parseToLuau(luau, item);
                luau.rawSetIndex(-2, @intCast(i));
            }
        },
    }
}

fn void_fn() void {}

fn valueFromLuau(luau: *Luau, index: i32) error{ InvalidType, NumberParsingError, StringParsingError, MemoryError, TableParsingError }!json.Value {
    return switch (luau.typeOf(index)) {
        .boolean => json.Value{ .bool = luau.toBoolean(index) },
        .nil => json.Value{ .null = void_fn() },
        .none => json.Value{ .null = void_fn() },
        .string => json.Value{ .string = luau.toString(index) catch return error.StringParsingError },
        .number => {
            const number = luau.toNumber(index) catch return error.NumberParsingError;
            if (@floor(number) == number) return json.Value{ .integer = @intFromFloat(number) } else return json.Value{ .float = number };
        },
        .table => {
            const is_array = luau.rawGetIndex(index, 1) != zlua.LuaType.nil;
            luau.pop(1);
            if (is_array) {
                var array = std.array_list.Managed(json.Value).init(luau.allocator());
                const array_len: usize = @intCast(@max(0, luau.objectLen(index)));

                for (1..array_len + 1) |array_index| {
                    _ = luau.rawGetIndex(index, @intCast(array_index));
                    const value = try valueFromLuau(luau, luau.getTop());
                    array.append(value) catch return error.MemoryError;
                    luau.pop(1);
                }
                return json.Value{ .array = array };
            } else {
                //Table is not array
                var map = std.StringArrayHashMap(json.Value).init(luau.allocator());

                luau.pushNil();
                while (luau.next(index)) {
                    const key = luau.toString(luau.getTop() - 1) catch return error.TableParsingError;
                    const value = try valueFromLuau(luau, luau.getTop());
                    map.put(key[0..], value) catch return error.MemoryError;
                    luau.pop(1);
                }
                return json.Value{ .object = map };
            }
        },
        else => return error.InvalidType,
    };
}

//Luau functions

fn load_fn(luau: *Luau) i32 {
    _ = luau.checkString(1);

    const json_string_raw = luau.toString(1) catch luauError(luau, "Failed to get json string from luau!");
    const json_string = json_string_raw[0..];
    const is_valid = json.validate(luau.allocator(), json_string) catch luauError(luau, "Memory error validating json!");

    if (!is_valid) {
        logger.err("Invalid JSON: {s}.", .{json_string});
        luauError(luau, "Invalid JSON.");
    }

    //We use leaky because Luau will clean up after module is built.
    const parsed_json = json.parseFromSliceLeaky(json.Value, luau.allocator(), json_string, .{}) catch |e| {
        logger.err("Error parsing json: {s}", .{@errorName(e)});
        luauError(luau, "Error parsing json.");
    };

    parseToLuau(luau, parsed_json);

    return 1;
}

fn dump_fn(luau: *Luau) i32 {
    _ = luau.checkType(1, .table);

    const value = valueFromLuau(luau, 1) catch |e| {
        logger.err("Error with valueFromLuau: {s}", .{@errorName(e)});
        luauError(luau, "Error with zig json parser!");
    };

    const json_formatter = json.fmt(value, .{});

    var json_string_writer = std.io.Writer.Allocating.init(luau.allocator());

    json_formatter.format(&json_string_writer.writer) catch |e| {
        logger.err("Error turning json to string: {s}", .{@errorName(e)});
        luauError(luau, "Error stringifying json!");
    };

    _ = luau.pushString(json_string_writer.writer.buffered());

    return 1;
}
