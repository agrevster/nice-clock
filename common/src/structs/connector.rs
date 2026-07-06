use crate::{
    VoidClockResult,
    structs::{color::Color, pos::Pos},
};

///Required to create a nice-clock connector.
pub trait ClockConnector {
    /// Used to set the `color` of a tile at the given `Pos`
    fn set_tile(self: Self, pos: Pos, color: Color) -> VoidClockResult;
    ///Updates the screen to show the most recent changes in tiles.
    fn update_screen(self: Self) -> VoidClockResult;
    ///Clears the screen
    fn clear_screen(self: Self) -> VoidClockResult;
    ///Sets the brightness of the display to the given `brightness`.
    ///**Values must be between 0 and 100 inclusive!**
    fn set_brightness(self: Self, brightness: u8) -> VoidClockResult;
}
