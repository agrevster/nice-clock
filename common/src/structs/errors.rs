use std::{error::Error, fmt::Display};

use crate::structs::pos::Pos;

///An exhaustive enum of all the errors the clock can return.
#[derive(Debug)]
pub enum ClockError {
    ///An error returned by the clock connector.
    ConnectorError(ConnectorError),
}

#[derive(Debug)]
pub enum ConnectorError {
    ///Returned when a tile is created with a position not in the confines of the screen.
    TileOutOfBounds(Pos),
}

impl ConnectorError {
    pub fn tile_out_of_bounds(pos: Pos) -> ClockError {
        ClockError::ConnectorError(ConnectorError::TileOutOfBounds(pos))
    }
}

impl Display for ClockError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ClockError::ConnectorError(connector_error) => match connector_error {
                ConnectorError::TileOutOfBounds(pos) => f.write_str("Tile out of bounds: {pos}"),
            },
        }
    }
}

impl Error for ClockError {}
