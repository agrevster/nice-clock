const std = @import("std");
const common = @import("../common.zig");

///Used to specify the creator of the clock module and how it should be retrieved.
///`builtin` => For modules used defined internally with Zig. (Just a pointer to the module)
///`custom` => For modules defined by users using Luau. (The Luau file's name)
pub const ClockModuleSource = union(enum) {
    ///A pointer to the clock module.
    builtin: *ClockModule,
    ///The Luau module file's name.
    custom: []const u8,
};

///The clock is made up of modules, each modules should serve a distinct purpose, ex displaying time.
pub const ClockModule = struct {
    ///The name of the module
    name: []const u8,
    ///The root component used to draw the module.
    root_component: common.components.RootComponent,
    ///How many seconds the module should be active for before switching
    time_limit_s: u64,
    ///Used to tell the clock's image store which images the module needs loaded.
    image_names: ?[]const []const u8,

    const logger = std.log.scoped(.module);

    ///Displays the module on the clock's screen.
    pub fn render(self: *ClockModule, clock: *common.Clock) void {
        self.root_component.render(clock, common.constants.fps, self.time_limit_s) catch |err| {
            logger.err("[{s}]: {s}", .{ self.name, @errorName(err) });
        };
    }
};
