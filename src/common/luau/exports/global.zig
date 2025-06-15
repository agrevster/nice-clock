const std = @import("std");
const zlua = @import("zlua");
const Luau = zlua.Lua;
const wrap = zlua.wrap;

///Sends the exported functions to luau.
pub fn load_export(luau: *Luau) void {
    luau.pushFunction(wrap(print));
    luau.setGlobal("print");
}

const print_logger = std.log.scoped(.luau_print);

fn appendu8SliceOrLog(array_list: *std.ArrayList(u8), slice: []const u8) void {
    if (array_list.appendSlice(slice)) {} else |e| {
        print_logger.err("Error appending slice to buffer. Slice: {s}, Err: {s}", .{ slice, @errorName(e) });
    }
}

fn print_at_index(luau: *Luau, i: i32, print_list: *std.ArrayList(u8), allocator: std.mem.Allocator) void {
    switch (luau.typeOf(i)) {
        .none => {
            appendu8SliceOrLog(print_list, "None ");
        },
        .nil => {
            appendu8SliceOrLog(print_list, "Nill ");
        },
        .string => {
            const val = luau.toString(i) catch "Error";
            appendu8SliceOrLog(print_list, std.fmt.allocPrint(allocator, "{s} ", .{val}) catch "Error");
        },
        .number => {
            const val = luau.toNumber(i) catch 0.0;
            appendu8SliceOrLog(print_list, std.fmt.allocPrint(allocator, "{d} ", .{val}) catch "Error");
        },
        .boolean => {
            const val = luau.toBoolean(i);
            appendu8SliceOrLog(print_list, std.fmt.allocPrint(allocator, "{} ", .{val}) catch "Error");
        },
        .table => {
            appendu8SliceOrLog(print_list, "{");
            luau.pushNil();
            while (luau.next(-2)) {
                const key = luau.toString(-2) catch std.fmt.allocPrint(allocator, "<{s}>", .{luau.typeNameIndex(-2)}) catch "Error";
                const value = luau.toString(-1) catch std.fmt.allocPrint(allocator, "<{s}>", .{luau.typeNameIndex(-1)}) catch "Error";
                appendu8SliceOrLog(print_list, std.fmt.allocPrint(allocator, "{s} = {s};", .{ key, value }) catch "Error");
                luau.pop(1);
            }
            luau.pop(1);
            appendu8SliceOrLog(print_list, "} ");
        },
        else => {
            appendu8SliceOrLog(print_list, std.fmt.allocPrint(allocator, "<{s}> ", .{luau.typeNameIndex(i)}) catch "Error");
        },
    }
}

fn print(luau: *Luau) i32 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var print_list = std.ArrayList(u8).init(arena.allocator());

    const arg_count: u31 = @max(0, luau.getTop());
    //Luau indexing starts at 1 (WTF)
    for (1..arg_count + 1) |i_usize| {
        const i: i32 = @intCast(i_usize);
        print_at_index(luau, i, &print_list, arena.allocator());
    }
    print_logger.info("{s}", .{print_list.items});

    return 0;
}
