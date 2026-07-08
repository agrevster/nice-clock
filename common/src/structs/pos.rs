///Used to represent the `x` and `y` position of a tile on the clock.
#[derive(Debug, PartialEq, Eq)]
pub struct Pos {
    pub x: u8,
    pub y: u8,
}

impl From<(u8, u8)> for Pos {
    fn from(value: (u8, u8)) -> Self {
        Pos {
            y: value.0,
            x: value.1,
        }
    }
}
