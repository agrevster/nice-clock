use std::{error::Error, fmt::Display, path::PathBuf};

use crate::clock::pos::Pos;

///An exhaustive enum of all the errors the clock can return.
#[derive(Debug)]
pub enum ClockError {
    ///Returned when a tile is created with a position not in the confines of the screen.
    TileOutOfBounds(Pos),
    ///Returned when an invalid argument is specified
    ///The first string is the argument name, the second is the given argument, and the third is the
    ///message of why it is wrong.
    ComponentInvalidArgument(String, String, String),

    ///Returned when an error occurs with a clock asset.
    AssetError(ClockAssetError),
}

#[derive(Debug)]
///Returned when an error occurs with a clock asset.
pub enum ClockAssetError {
    ///Returned when a BDF font cannot be parsed.
    BDFParsing(String, String),
    ///Returned when a PPM image cannot be parsed.
    PPMParsing(String, String),
    ///Returned when an IO error occurs
    FileError(std::io::Error, PathBuf),
    ///Returned when an asset cannot be found.
    AssetNotFound(String),
}

impl ClockError {
    ///Returns a `ClockError` given the `pos` of the tile out of bounds.
    pub fn tile_out_of_bounds(pos: Pos) -> ClockError {
        ClockError::TileOutOfBounds(pos)
    }

    ///Returns a `ClockError` for a component that is given an invalid argument.
    pub fn component_invalid_argument(
        argument_name: String,
        argument_value: String,
        message: String,
    ) -> ClockError {
        ClockError::ComponentInvalidArgument(argument_name, argument_value, message)
    }

    ///Returns a `ClockError` for when an issue occurs when parsing a BDF font.
    // /`font_name`,`message`
    pub fn bdf_font_parsing(font_name: &str, message: &str) -> ClockError {
        ClockError::AssetError(ClockAssetError::BDFParsing(
            font_name.to_string(),
            message.to_string(),
        ))
    }

    ///Returns a `ClockError` for when an issue occurs when parsing a PPM Image.
    // /`image_name`,`message`
    pub fn ppm_image_parsing(image_name: &str, message: &str) -> ClockError {
        ClockError::AssetError(ClockAssetError::PPMParsing(
            image_name.to_string(),
            message.to_string(),
        ))
    }

    ///Converts a `std::io::Error` into a `ClockError`
    pub fn file_error(err: std::io::Error, filepath: PathBuf) -> ClockError {
        ClockError::AssetError(ClockAssetError::FileError(err, filepath))
    }

    ///Returns a `ClockError` for when an asset can't be found.
    pub fn asset_not_found(asset_name: String) -> ClockError {
        ClockError::AssetError(ClockAssetError::AssetNotFound(asset_name))
    }
}

impl Display for ClockError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ClockError::TileOutOfBounds(pos) => write!(f, "Tile out of bounds: {pos:?}"),
            ClockError::ComponentInvalidArgument(arg_name, given_arg, why) => {
                write!(
                    f,
                    "Invalid argument value: {given_arg} for arg: {arg_name}. {why}"
                )
            }
            ClockError::AssetError(clock_asset_error) => match clock_asset_error {
                ClockAssetError::BDFParsing(font_name, message) => {
                    write!(
                        f,
                        "Failed to parse the header of BDF font: {font_name}; {message}"
                    )
                }
                ClockAssetError::PPMParsing(image_name, message) => {
                    write!(f, "Failed to parse a PPM image: {image_name}; {message}")
                }
                ClockAssetError::FileError(error, filepath) => {
                    write!(
                        f,
                        "There was an error trying to work with file: {filepath:?}: {error:?}"
                    )
                }
                ClockAssetError::AssetNotFound(asset_filename) => {
                    write!(f, "Asset not found: {asset_filename}!")
                }
            },
        }
    }
}

impl Error for ClockError {}
