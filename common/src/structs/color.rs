///Used to represent RGB colors.
#[derive(PartialEq, Eq, Default)]
pub struct Color {
    pub r: u8,
    pub g: u8,
    pub b: u8,
}

impl Color {
    ///Returns a new `Color` with `r` set to `255`.
    pub fn red() -> Color {
        Color { r: 255, g: 0, b: 0 }
    }

    ///Returns a new `Color` with `g` set to `255`.
    pub fn green() -> Color {
        Color { r: 0, g: 255, b: 0 }
    }

    ///Returns a new `Color` with `b` set to `255`.
    pub fn blue() -> Color {
        Color { r: 0, g: 0, b: 255 }
    }

    ///Returns a new `Color` with `r`, `g`, and `b` set to `255`.
    pub fn white() -> Color {
        Color {
            r: 255,
            g: 255,
            b: 255,
        }
    }

    ///Returns a new `Color` with `r`, `g`, and `b` set to `0`.
    pub fn black() -> Color {
        Color { r: 0, g: 0, b: 0 }
    }
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
