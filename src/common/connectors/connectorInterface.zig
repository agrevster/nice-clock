const common = @import("../common.zig");

pub const ConnectorError = error{
    ///Returned when a tile set to a position that is out of the bounds of the clock
    TileOutOfBounds,
};

/// The different types of `clock connectors`
/// **Simulator** - Used to simulate a clock via desktop gui
/// **Hardware** - The connector used by the Raspberry PI to display to the led matrix.
pub const ConnectorType = enum { Simulator, Hardware };

/// A shared interface used by all `clock connectors`.
pub const ConnectorInterface = struct {
    type: ConnectorType,
    /// Used to store `*@This` to allow functions to use `self` to access the parent struct's fields.
    ///
    /// Inside of interface functions add this line to use `ctx`
    ///```zig
    /// const self: *@(This) = @ptrCast(@alignCast(ctx));
    ///```
    ctx: *anyopaque,

    /// Used to set the color of a tile at the given `x` and `y`
    /// *The* `ctx` *param should always be set to the `ctx field` of what ever interface you are using.*
    setTile: *const fn (ctx: *anyopaque, y: u8, x: u8, color: common.Color) ConnectorError!void,
    /// Updated the screen to reflect the current tile buffer
    /// *The* `ctx` *param should always be set to the `ctx field` of what ever interface you are using.*
    updateScreen: *const fn (ctx: *anyopaque) void,
    /// Clears the tile buffer
    /// **You must also update the screen if you wish to display a blank screen!**
    /// *The* `ctx` *param should always be set to the `ctx field` of what ever interface you are using.*
    clearScreen: *const fn (ctx: *anyopaque) void,
    ///Used to set the brightness of the clock's display. **Does not require updating.**
    /// *The* `ctx` *param should always be set to the `ctx field` of what ever interface you are using.*
    setBrightness: *const fn (ctx: *anyopaque, brightness: u8) void,
};
