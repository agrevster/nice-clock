const std = @import("std");
const common = @import("../common.zig");
const zlua = @import("zlua");
const Luau = zlua.Lua;
const components = common.components;
const componentFn = common.luau.exports.nice_clock.component_fn;
const ClockComponentTable = common.luau.exports.nice_clock.ClockComponentTable;
const AnimationTable = common.luau.exports.nice_clock.AnimationTable;
const luau_error = common.luau.loader.luau_error;
const logger = common.luau.loader.logger;

const LuauComponentType = enum(u8) {
    TileComponent,
    BoxComponent,
    CircleComponent,
    ImageComponent,
    CharComponent,
    TextComponent,
    WrappedTextComponent,
    HorizontalScrollingTextComponent,
    VerticalScrollingTextComponent,
};

pub const LuauArg = union(enum) {
    string: [:0]const u8,
    int: zlua.Integer,
    bool: bool,
    float: zlua.Number,
    char: u8,
    pos: common.components.ComponentPos,
    animation: AnimationTable,
    color: common.Color,

    const ArgFetchError = error{ NotInUnion, IndexNotInArray, ValidationError };

    pub fn getStringOrError(list: []LuauArg, index: usize) ArgFetchError![:0]const u8 {
        const arg = try getArgOrError(list, index);
        switch (arg) {
            .string => |s| return s,
            else => return error.NotInUnion,
        }
    }

    pub fn getIntOrError(list: []LuauArg, index: usize) ArgFetchError!zlua.Integer {
        const arg = try getArgOrError(list, index);
        switch (arg) {
            .int => |i| return i,
            else => return ArgFetchError.NotInUnion,
        }
    }
    pub fn getU8IntOrError(list: []LuauArg, index: usize) ArgFetchError!u8 {
        const arg = try getArgOrError(list, index);
        switch (arg) {
            .int => |i| return std.math.lossyCast(u8, i),
            else => return ArgFetchError.NotInUnion,
        }
    }

    pub fn getI8IntOrError(list: []LuauArg, index: usize) ArgFetchError!i8 {
        const arg = try getArgOrError(list, index);
        switch (arg) {
            .int => |i| return std.math.lossyCast(i8, i),
            else => return ArgFetchError.NotInUnion,
        }
    }

    pub fn getI32IntOrError(list: []LuauArg, index: usize) ArgFetchError!i32 {
        const arg = try getArgOrError(list, index);
        switch (arg) {
            .int => |i| return std.math.lossyCast(i32, i),
            else => return ArgFetchError.NotInUnion,
        }
    }

    pub fn getFloatOrError(list: []LuauArg, index: usize) ArgFetchError!zlua.Number {
        const arg = try getArgOrError(list, index);
        switch (arg) {
            .float => |f| return f,
            else => return ArgFetchError.NotInUnion,
        }
    }

    pub fn getBoolOrError(list: []LuauArg, index: usize) ArgFetchError!bool {
        const arg = try getArgOrError(list, index);
        switch (arg) {
            .bool => |b| return b,
            else => return ArgFetchError.NotInUnion,
        }
    }

    pub fn getCharOrError(list: []LuauArg, index: usize) ArgFetchError!u8 {
        const arg = try getArgOrError(list, index);
        switch (arg) {
            .string => |b| {
                if (b.len > 1 or b.len == 0) {
                    std.log.err("Invalid char length: {d}", .{b.len});
                    return ArgFetchError.ValidationError;
                }
                return b[0];
            },
            else => return ArgFetchError.NotInUnion,
        }
    }

    pub fn getFontOrError(list: []LuauArg, index: usize) ArgFetchError!common.font.FontStore {
        const arg = try getArgOrError(list, index);
        switch (arg) {
            .string => |b| {
                return std.meta.stringToEnum(common.font.FontStore, b) orelse {
                    std.log.err("Invalid font: {s}", .{b});
                    return ArgFetchError.ValidationError;
                };
            },
            else => return ArgFetchError.NotInUnion,
        }
    }

    pub fn getColorOrError(list: []LuauArg, index: usize) ArgFetchError!common.Color {
        const arg = try getArgOrError(list, index);
        switch (arg) {
            .color => |b| return b,
            else => return ArgFetchError.NotInUnion,
        }
    }

    pub fn getPosOrError(list: []LuauArg, index: usize) ArgFetchError!common.components.ComponentPos {
        const arg = try getArgOrError(list, index);
        switch (arg) {
            .pos => |b| return b,
            else => return ArgFetchError.NotInUnion,
        }
    }

    pub fn getAnimationOrError(list: []LuauArg, index: usize) ArgFetchError!AnimationTable {
        const arg = try getArgOrError(list, index);
        switch (arg) {
            .animation => |b| return b,
            else => return ArgFetchError.NotInUnion,
        }
    }

    pub fn getArgOrError(list: []LuauArg, index: usize) ArgFetchError!LuauArg {
        if (index >= list.len or index < 0) return ArgFetchError.IndexNotInArray;
        return list[index];
    }
};

pub const LuauComponentConstructorError = error{ BadValue, MemoryError, OtherError } || LuauArg.ArgFetchError;
const LuauComponentConstructor = *const fn (args: []LuauArg, allocator: std.mem.Allocator) LuauComponentConstructorError!*components.AnyComponent;

fn generateLuauComponentConstructors() []const LuauComponentConstructor {
    const luau_component_enum_fields = @typeInfo(LuauComponentType).@"enum".fields;

    var creator_functions: [luau_component_enum_fields.len]LuauComponentConstructor = undefined;

    comptime var i = 0;
    inline while (i < luau_component_enum_fields.len) : (i += 1) {
        const component_type_for_enum = @field(components, luau_component_enum_fields[i].name);
        const constructor_fn = @field(component_type_for_enum, "from_luau");
        creator_functions[i] = constructor_fn;
    }

    const creator_functions_const = creator_functions;
    return creator_functions_const[0..];
}

pub const RootComponentImportError = error{ MemoryError, OtherError, InvalidComponentError, LuauParseError } || LuauComponentConstructorError;
pub fn rootComponentFromLuau(luau: *Luau, allocator: std.mem.Allocator) RootComponentImportError!*components.RootComponent {
    const component_constructors = comptime generateLuauComponentConstructors();
    _ = luau.getField(1, "components");
    const component_array = luau.toAnyInternal([]ClockComponentTable, luau.allocator(), true, -1) catch {
        return error.LuauParseError;
    };

    const parsed_components = allocator.alloc(components.AnyComponent, component_array.len) catch return error.MemoryError;

    for (component_array, 0..) |luau_component, i| {
        if (luau_component.number >= component_constructors.len) return error.InvalidComponentError;
        if (component_constructors[luau_component.number](luau_component.props, allocator)) |component| {
            parsed_components[i] = component.*;
        } else |e| {
            logger.err("There was an error parsing component: {d} from Luau: {s}.", .{ luau_component.number, @errorName(e) });
        }
    }

    var root = allocator.create(components.RootComponent) catch return error.MemoryError;
    root.components = parsed_components;

    return root;
}

pub fn generateLuauComponentBuilderFunctions(luau: *Luau) void {
    for (std.enums.values(LuauComponentType), 0..) |component, index| {
        // And this is why we use Luau for modules... Imagine having to do all this to change a string
        const enum_tag = @tagName(component);
        const size = std.mem.replacementSize(u8, enum_tag, "Component", "");
        const component_function_name = luau.allocator().allocSentinel(u8, size, '\x00') catch luau_error(luau, "Memory error with generating builder function.");
        _ = std.mem.replace(u8, enum_tag, "Component", "", component_function_name);
        _ = std.ascii.lowerString(component_function_name, component_function_name);

        luau.pushInteger(@intCast(index));
        luau.pushClosure(zlua.wrap(componentFn), 1);
        luau.setField(-2, component_function_name);
    }
}

pub fn generateLuauFontFields(luau: *Luau) void {
    luau.newTable();
    for (std.enums.values(common.font.FontStore)) |component| {
        const enum_tag = @tagName(component);
        _ = luau.pushStringZ(enum_tag);
        luau.setField(-2, enum_tag);
    }
    luau.setField(-2, "fonts");
}
