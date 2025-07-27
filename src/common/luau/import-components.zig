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

///Each field of this enum represents a component from `common.components` that will be pushed to the luau module builder.
///The component struct must have the function _from_luau(args: []LuauArg, allocator: std.mem.Allocator) LuauComponentConstructorError!*AnyComponent_.
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

/// Represents a single argument passed to a Luau clock component builder function.
/// To support additional types or table fields from Luau, modify component_fn in `luau/exports/nice-clock.zig`.
///
/// Each field in the union is used to represent a different type.
/// Parsing specific type variants like u8 for int should be done as a method and not by adding a separate field.
/// Structs are different story... Avoid adding new structs if at all possible.
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

///Represents all of the errors that are thrown by a component's the from_luau function.
pub const LuauComponentConstructorError = error{ BadValue, MemoryError, OtherError } || LuauArg.ArgFetchError;
//Used to represent a pointer to a from_luau function. Every function used to create a component from a luau builder function MUST follow this.
const LuauComponentConstructor = *const fn (args: []LuauArg, allocator: std.mem.Allocator) LuauComponentConstructorError!*components.AnyComponent;

///Creates a list of functions used to create components for luau component builder functions.
///Each index corresponds to the index of the LuauComponentType field which should be the name of a component struct with a from_luau function.
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

///The possible errors from importing a RootComponent from luau.
pub const RootComponentImportError = error{ MemoryError, OtherError, InvalidComponentError, LuauParseError } || LuauComponentConstructorError;

///Attempts to read a component builder table in luau and returns a RootComponent or error.
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

///Pushes a luau function for each field in the LuauComponentType enum use to build components form luau.
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

///Pushes each field of the FontStore enum to Luau.
///Used to give easy references to all of the available fonts.
pub fn generateLuauFontFields(luau: *Luau) void {
    luau.newTable();
    for (std.enums.values(common.font.FontStore)) |component| {
        const enum_tag = @tagName(component);
        _ = luau.pushStringZ(enum_tag);
        luau.setField(-2, enum_tag);
    }
    luau.setField(-2, "fonts");
}
