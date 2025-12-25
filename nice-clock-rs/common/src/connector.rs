use crate::structs::Color;

///Errors returned by a clock connector
pub enum ConnectorError {
    ///Returned if a clock tile is outside of the clock's 32x64 screen.
    TileOutOfBounds,
}

///A set of functions used to modify pixels on a clock connector.
pub trait Connector {
    ///Clears the screen without updating.
    fn clear();
    ///Sets the color of a given tile at pos `y`,`x` to the given `color`.
    fn set_tile(y: u8, x: u8, color: Color) -> Result<(), ConnectorError>;
    ///Updates the screen.
    fn update();
}
