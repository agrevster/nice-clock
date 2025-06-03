const std = @import("std");
const common = @import("../common.zig");

pub const ModuleLoaderInterface = struct {
    ///Loads all modules
    load: *const fn (*std.mem.Allocator) []common.module.ClockModule,
    ///Unloads all modules
    unload: *const fn (*std.mem.Allocator) void,
};
