use std::{
    fmt::Debug,
    thread,
    time::{Duration, Instant},
};

use chrono::TimeDelta;

use crate::{
    HEIGHT, VoidClockResult, WIDTH,
    structs::{color::Color, connector::ClockConnector, pos::Pos},
};

///Trait used for all clock components. Each component must implement this
pub trait Component {
    ///The name of the component.
    ///**It is preferred to inline this!**
    fn name(&self) -> String;

    ///The function used to draw the specific component on the `clock`.
    fn draw(&self, clock: &mut dyn ClockConnector) -> VoidClockResult;
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
    ///Clears the screen, draws a given `RootComponent` onto the `clock`, and blocks the thread until the `time_limit`
    ///is exceeded.
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

    pub fn new(components: Vec<Box<dyn Component>>) -> RootComponent {
        RootComponent { components }
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

///Used to draw a single tile on the screen at the given `Pos` and with the given `Color`
pub struct TileComponent {
    pub color: Color,
    pub pos: Pos,
}

impl Component for TileComponent {
    #[inline]
    fn name(&self) -> String {
        "tile".to_string()
    }
    fn draw(&self, clock: &mut dyn ClockConnector) -> VoidClockResult {
        clock.set_tile(&self.pos, &self.color)
    }
}

///Used to draw a box on the screen starting at the given
pub struct BoxComponent {
    pub color: Color,
    pub pos: Pos,
    pub fill_inside: bool,
    pub width: u8,
    pub height: u8,
}

impl Component for BoxComponent {
    #[inline]
    fn name(&self) -> String {
        "box".to_string()
    }
    fn draw(&self, clock: &mut dyn ClockConnector) -> VoidClockResult {
        self.pos.validate()?;

        let x0 = self.pos.x;
        let y0 = self.pos.y;

        // Nothing to draw for empty box
        if self.width == 0 || self.height == 0 {
            return Ok(());
        }

        let x_end = (x0 + self.width).min(WIDTH);
        let y_end = (y0 + self.height).min(HEIGHT);
        let last_col = x0 + self.width - 1;
        let last_row = y0 + self.height - 1;

        //Fill inside of box
        if self.fill_inside {
            for y in y0..y_end {
                for x in x0..x_end {
                    clock.set_tile(&Pos::from((x, y)), &self.color)?;
                }
            }
            return Ok(());
        }

        // Outline only: draw the four edges
        // Top row always valid because y0 < HEIGHT
        for x in x0..x_end {
            clock.set_tile(&(x, y0).into(), &self.color)?;
        }

        // Bottom row if it's distinct from the top row and still on-grid.
        if last_row != y0 && last_row < HEIGHT {
            for x in x0..x_end {
                clock.set_tile(&(x, last_row).into(), &self.color)?;
            }
        }

        // Left/right columns restricted to the rows strictly between
        // top and bottom.
        let inner_start = y0 + 1;
        let inner_end = last_row.saturating_sub(1).min(y_end.saturating_sub(1));

        if inner_start <= inner_end {
            for y in inner_start..=inner_end {
                clock.set_tile(&(x0, y).into(), &self.color)?;
                if last_col != x0 && last_col < WIDTH {
                    clock.set_tile(&(last_col, y).into(), &self.color)?;
                }
            }
        }
        Ok(())
    }
}
