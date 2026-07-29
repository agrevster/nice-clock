///A `Result` of `void` or `ClockError`.
pub type VoidClockResult = Result<(), clock::errors::ClockError>;

///Stores structures defined for use in nice-clock
pub mod clock;
///Utilities
pub mod utils;

///The width of the clock's screen.
pub const WIDTH: u8 = 64;
///The height of the clock's screen.
pub const HEIGHT: u8 = 32;
///The FPS of the clock.
pub const FPS: u8 = 60;
