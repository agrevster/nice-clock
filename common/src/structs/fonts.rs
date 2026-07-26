use std::{
    char, collections::HashMap, fs::read_to_string, path::PathBuf, str::FromStr, sync::OnceLock,
};

use strum::{EnumCount, EnumString, VariantNames};

use crate::utils::{LogUnwrap, assets_dir};
use crate::{VoidClockResult, structs::errors::ClockError};

#[derive(Debug)]
pub struct BDFFont {
    pub width: u8,
    pub height: u8,
    pub default_char: char,
    pub glyphs: HashMap<char, Vec<u8>>,
}

impl BDFFont {
    ///Creates a BDF font from given `data`, which should be the contents of a BDF file.
    ///`font_name` is used for logging purposes.
    fn parse(data: &str, font_name: &str) -> Result<BDFFont, ClockError> {
        let mut width: u8 = 0;
        let mut height: u8 = 0;
        let mut default_char: char = 0 as char;

        let mut current_char: Option<char> = None;
        let mut in_bitmap = false;
        let mut bitmap: HashMap<char, Vec<u8>> = HashMap::new();
        let mut char_bytes: Vec<u8> = Vec::new();

        for line in data.lines() {
            let line_split = line.split_whitespace().collect::<Vec<&str>>();
            if let Some(first) = line_split.first() {
                match *first {
                    "FONTBOUNDINGBOX" => {
                        width =
                            get_font_key(1, &line_split, font_name, "width", "FONTBOUNDINGBOX")?;
                        height =
                            get_font_key(2, &line_split, font_name, "height", "FONTBOUNDINGBOX")?;
                    }
                    "DEFAULT_CHAR" => {
                        default_char = char::from_u32(get_font_key(
                            1,
                            &line_split,
                            font_name,
                            "default_char",
                            "DEFAULT_CHAR",
                        )?)
                        .ok_or_else(|| {
                            ClockError::bdf_font_parsing(font_name, "Failed to parse DEFAULT_CHAR.")
                        })?;
                    }
                    "ENCODING" => {
                        current_char = Some(
                            char::from_u32(get_font_key::<u32>(
                                1,
                                &line_split,
                                font_name,
                                "current_char",
                                "ENCODING",
                            )?)
                            .ok_or_else(|| {
                                ClockError::bdf_font_parsing(
                                    font_name,
                                    "Failed to parse ENCODING: current_char as char.",
                                )
                            })?,
                        );
                    }
                    "BITMAP" => {
                        in_bitmap = true;
                    }
                    "ENDCHAR" => {
                        if let Some(current_char) = current_char {
                            bitmap.insert(current_char, char_bytes.clone());
                            char_bytes.clear();
                        }

                        in_bitmap = false;
                        current_char = None;
                    }
                    _ => {
                        if in_bitmap {
                            if current_char.is_none() {
                                return Err(ClockError::bdf_font_parsing(
                                    font_name,
                                    "Attempted to parse bitmap for unset char!",
                                ));
                            }

                            let bytes = u16::from_str_radix(line, 16).map_err(|_| {
                                ClockError::bdf_font_parsing(
                                    font_name,
                                    &format!(
                                        "Failed to parse hex bitmap row on char: {}.",
                                        current_char.unwrap_or(' ')
                                    ),
                                )
                            })?;
                            let num_bytes = (line.len() + 1) / 2;
                            for i in 0..num_bytes {
                                let shift = 8 * (num_bytes - 1 - i);
                                let byte = ((bytes >> shift) & 0xFF) as u8;
                                char_bytes.push(byte);
                            }
                        }
                    }
                }
            }
        }

        Ok(Self {
            width,
            height,
            default_char,
            glyphs: bitmap,
        })
    }
}

/// Used to represent the fonts available for use with the clock.
/// In order to access these fonts, Font::load() must be called to load of of the available fonts
/// into memory
#[derive(EnumCount, VariantNames, EnumString)]
pub enum Font {
    Font12x24,
    Font5x8_2,
    Font5x5,
    Font5x8,
    Font6x12,
    Font6x13,
    Font7x13,
    Font7x14,
}

static FONTS: OnceLock<[BDFFont; Font::COUNT]> = OnceLock::new();

pub fn load_font_from_file(path: PathBuf, font_name: &str) -> Result<BDFFont, ClockError> {
    let file_content = read_to_string(path.clone()).map_err(|e| ClockError::file_error(e, path))?;

    BDFFont::parse(&file_content, font_name)
}

impl Font {
    ///Loads a BDF font from a given `path` from the filesystem.
    ///**This should only be called once, and will panic if set more than once.**
    pub fn load_fonts() -> VoidClockResult {
        let mut buffer: Vec<BDFFont> = Vec::with_capacity(Font::COUNT);

        for fontname in Font::VARIANTS {
            let mut path = assets_dir();
            let mut filename = fontname.replace("Font", "");
            filename.push_str(".bdf");
            path.push("fonts");
            path.push(filename);

            buffer.push(load_font_from_file(path, fontname)?);
        }

        FONTS
            .set(
                buffer
                    .try_into()
                    .expect("Failed to convert font buffer into array!"),
            )
            .expect("Fone store already initialized!");

        Ok(())
    }

    ///Gets a font from the font store.
    ///**Panics if font store is not initialized.**
    pub fn get(self) -> &'static BDFFont {
        let fonts = FONTS.get().unwrap_and_log("Font store not initialized!");
        &fonts[self as usize]
    }
}

fn get_font_key<T: FromStr>(
    index: usize,
    line: &Vec<&str>,
    font_name: &str,
    var_name: &str,
    key_name: &str,
) -> Result<T, ClockError> {
    Ok(line
        .get(index)
        .ok_or_else(|| {
            ClockError::bdf_font_parsing(
                font_name,
                &format!("Invalid {key_name} missing {var_name}."),
            )
        })?
        .parse()
        .map_err(|_| {
            ClockError::bdf_font_parsing(
                font_name,
                &format!("Failed to parse {key_name}: {var_name} as int."),
            )
        })?)
}

#[cfg(test)]
fn print_char(font: &BDFFont, chr: char) {
    let glyph = font.glyphs.get(&chr).unwrap();

    let bytes_per_row: usize = (font.width + 7).checked_div(8).unwrap() as usize;

    for row in 0..std::cmp::min(glyph.len(), font.height as usize) {
        let row_start = row * bytes_per_row;
        let row_end = row_start + bytes_per_row;
        let row_bytes = glyph.as_slice();

        let mut tile_index: u8 = 0;
        for byte in &row_bytes[row_start..row_end] {
            for bit in 0..8 {
                if tile_index >= font.width {
                    break;
                };
                if byte & 0x80 >> bit != 0 {
                    print!("#");
                } else {
                    print!(".");
                }
                tile_index += 1;
            }
        }
        println!("");
    }
}

#[test]
fn test_parse5x8() {
    let font = BDFFont::parse(include_str!("../../../assets/fonts/5x8.bdf"), "5x8")
        .expect("Failed to parse BDF!");
    assert_eq!(font.width, 5);
    assert_eq!(font.height, 8);
    assert_eq!(font.default_char, char::from_u32(0).unwrap());
    assert_eq!(font.glyphs.len(), 1426);
    print_char(&font, '!');
    print_char(&font, 'P');
}

#[test]
fn test_parse12x24() {
    let font = BDFFont::parse(include_str!("../../../assets/fonts/12x24.bdf"), "12x24")
        .expect("Failed to parse BDF!");
    assert_eq!(font.width, 12);
    assert_eq!(font.height, 24);
    assert_eq!(font.default_char, char::from_u32(32).unwrap());
    assert_eq!(font.glyphs.len(), 916);
    print_char(&font, '!');
    print_char(&font, 'P');
}

#[test]
fn test_validate_all_fonts_from_store() {
    Font::load_fonts().unwrap();

    for font_name in Font::VARIANTS {
        let font = Font::from_str(font_name).unwrap().get();
        //Replacing _2 fixes error thrown by 5x8_2
        let font_name = font_name.replace("Font", "").replace("_2", "");

        let split = font_name.split("x").collect::<Vec<&str>>();

        let width: u8 = split[0].parse().expect("Failed to parse font width!");
        let height: u8 = split[1]
            .replace(".bdf", "")
            .parse()
            .expect("Failed to parse font height!");

        assert_eq!(width, font.width, "{font_name}");
        assert_eq!(height, font.height, "{font_name}");
    }
}
