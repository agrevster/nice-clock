pub const loader = @import("loader.zig");

///Luau modules created by zig for use in the clock modules.
pub const exports = struct {
    pub const global = @import("exports/global.zig");
};
