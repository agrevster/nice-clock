use crate::{HEIGHT, WIDTH, clock::errors::ClockError};

///Used to represent the `x` and `y` position of a tile on the clock.
#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub struct Pos {
    pub x: u8,
    pub y: u8,
}

impl Pos {
    ///Validates the given `Pos` to ensure the `x` and `y` are within the bounds of the clock.
    ///If they are not returns a `TileOutOfBounds` error.
    pub fn validate(&self) -> Result<&Pos, ClockError> {
        if self.x >= WIDTH || self.y >= HEIGHT {
            Err(ClockError::tile_out_of_bounds(*self))
        } else {
            Ok(self)
        }
    }
}

impl From<(u8, u8)> for Pos {
    fn from(value: (u8, u8)) -> Self {
        Pos {
            y: value.0,
            x: value.1,
        }
    }
}

impl From<Pos> for (u8, u8) {
    fn from(value: Pos) -> (u8, u8) {
        (value.y, value.x)
    }
}
