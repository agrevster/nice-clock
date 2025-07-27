pub const loader = @import("loader.zig");
pub const import_components = @import("import-components.zig");

///Luau modules created by Zig for use in the clock modules.
pub const exports = struct {
    pub const global = @import("exports/global.zig");
    pub const time = @import("exports/time.zig");
    pub const nice_clock = @import("exports/nice-clock.zig");
};
