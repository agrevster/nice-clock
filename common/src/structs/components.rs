use std::{
    fmt::Debug,
    thread,
    time::{Duration, Instant},
};

use chrono::TimeDelta;

use crate::{VoidClockResult, structs::connector::ClockConnector};

///Trait used for all clock components. Each component must implement this
pub trait Component {
    ///The name of the component.
    ///**It is preferred to inline this!**
    fn name(&self) -> String;

    ///The function used to draw the specific component on the `clock`.
    fn draw(&self, clock: &dyn ClockConnector) -> VoidClockResult;

    //TODO: Animations
}

///The starting point for a clock module.
///Run `draw` to draw the module on screen.
//TODO: Animations
pub struct RootComponent {
    components: Vec<Box<dyn Component>>,
}

impl RootComponent {
    //TODO: Animations
    pub fn render(
        &self,
        clock: &mut impl ClockConnector,
        time_limit: TimeDelta,
    ) -> VoidClockResult {
        clock.clear_screen()?;
        //How long the components took to draw
        let draw_time = Instant::now();

        for component in &self.components {
            component.draw(clock)?;
        }

        clock.update_screen()?;

        // Frame rate normalization
        let time_limit = time_limit.to_std().unwrap_or(Duration::from_secs(0));
        if let Some(remaining_time) = time_limit.checked_sub(draw_time.elapsed()) {
            thread::sleep(remaining_time);
        }

        Ok(())
    }
}

impl Debug for RootComponent {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let mut builder = f.debug_list();
        for comp in &self.components {
            builder.entry(&comp.name());
        }
        builder.finish()
    }
}
