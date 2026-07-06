use crate::{VoidClockResult, structs::connector::ClockConnector};

pub trait Component {
    fn draw(clock: &impl ClockConnector) -> VoidClockResult;
}
