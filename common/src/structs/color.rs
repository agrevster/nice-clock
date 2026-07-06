///Used to represent RGB colors.
#[derive(PartialEq, Eq)]
pub struct Color {
    r: u8,
    g: u8,
    b: u8,
}

impl From<(u8, u8, u8)> for Color {
    ///Creates a color from a `u8` tuple.
    ///The first item in the tuple is `r`
    ///The second item in the tuple is `g`
    ///The third item in the tuple is `b`
    fn from(value: (u8, u8, u8)) -> Self {
        Color {
            r: value.0,
            g: value.1,
            b: value.2,
        }
    }
}
