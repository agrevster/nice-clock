use std::{error::Error, fmt::Display};

///An exhaustive enum of all the errors the clock can return.
#[derive(Debug)]
pub enum ClockError {}

impl Display for ClockError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("Error!")
    }
}

impl Error for ClockError {}
