use std::{error::Error, fmt::Display};

use crate::structs::pos::Pos;

///An exhaustive enum of all the errors the clock can return.
#[derive(Debug)]
pub enum ClockError {
    ///An error returned by the clock connector.
    ConnectorError(ConnectorError),
    ///And error returned by a clock component.
    ComponentError(ComponentError),
}

#[derive(Debug)]
pub enum ConnectorError {
    ///Returned when a tile is created with a position not in the confines of the screen.
    TileOutOfBounds(Pos),
}

#[derive(Debug)]
pub enum ComponentError {
    ///Returned when an invalid argument is specified
    ///The first string is the argument name, the second is the given argument, and the third is the
    ///message of why it is wrong.
    InvalidArgumentValue(String, String, String),
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
                ConnectorError::TileOutOfBounds(pos) => write!(f, "Tile out of bounds: {pos:?}"),
            },
            ClockError::ComponentError(component_error) => match component_error {
                ComponentError::InvalidArgumentValue(arg_name, given_arg, why) => {
                    write!(
                        f,
                        "Invalid argument value: {given_arg} for arg: {arg_name}. {why}"
                    )
                }
            },
        }
    }
}

impl Error for ClockError {}
