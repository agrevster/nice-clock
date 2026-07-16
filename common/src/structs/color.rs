use std::num::ParseIntError;

///Used to represent RGB colors.
#[derive(PartialEq, Eq, Default, Clone, Copy, Debug)]
pub struct Color {
    pub r: u8,
    pub g: u8,
    pub b: u8,
}

impl Color {
    ///Converts a color into it's hexadecimal representation.
    pub fn to_hex(self) -> String {
        format!("#{:02X}{:02X}{:02X}", self.r, self.g, self.b)
    }

    ///Attempts to convert a hexadecimal string into a `Color`.
    ///If the conversion fails a `ParseIntError` is returned.
    pub fn from_hex(hex_string: &str) -> Result<Color, ParseIntError> {
        Ok(Self {
            r: u8::from_str_radix(&hex_string[1..3], 16)?,
            g: u8::from_str_radix(&hex_string[3..5], 16)?,
            b: u8::from_str_radix(&hex_string[5..7], 16)?,
        })
    }

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

#[test]
fn to_hex() {
    assert_eq!(Color::white().to_hex(), "#FFFFFF");
    assert_eq!(Color::white().to_hex(), "#FFFFFF");
    assert_eq!(Color::black().to_hex(), "#000000");
    assert_eq!(Color::red().to_hex(), "#FF0000");
    assert_eq!(Color::green().to_hex(), "#00FF00");
    assert_eq!(Color::blue().to_hex(), "#0000FF");
    assert_eq!(Color::from((17, 51, 155)).to_hex(), "#11339B");
}

#[test]
fn from_hex() {
    assert_eq!(Color::from_hex("#FFFFFF").unwrap(), Color::white());
    assert_eq!(Color::from_hex("#000000").unwrap(), Color::black());
    assert_eq!(Color::from_hex("#FF0000").unwrap(), Color::red());
    assert_eq!(Color::from_hex("#00FF00").unwrap(), Color::green());
    assert_eq!(Color::from_hex("#0000FF").unwrap(), Color::blue());
    assert_eq!(
        Color::from_hex("#11339B").unwrap(),
        Color::from((17, 51, 155))
    );
    assert!(Color::from_hex("#NOTHEX").is_err());
}
