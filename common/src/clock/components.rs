use std::{
    fmt::Debug,
    thread,
    time::{Duration, Instant},
};

use chrono::TimeDelta;

use crate::{
    HEIGHT, VoidClockResult, WIDTH,
    clock::{color::Color, connector::ClockConnector, errors::ClockError, fonts::Font, pos::Pos},
    utils::LogUnwrap,
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

///Used to draw a box on the screen starting at the given `Pos`
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
                    clock.set_tile(&Pos::from((y, x)), &self.color)?;
                }
            }
            return Ok(());
        }

        // Outline only: draw the four edges
        // Top row always valid because y0 < HEIGHT
        for x in x0..x_end {
            clock.set_tile(&(y0, x).into(), &self.color)?;
        }

        // Bottom row if it's distinct from the top row and still on-grid.
        if last_row != y0 && last_row < HEIGHT {
            for x in x0..x_end {
                clock.set_tile(&(last_row, x).into(), &self.color)?;
            }
        }

        // Left/right columns restricted to the rows strictly between
        // top and bottom.
        let inner_start = y0 + 1;
        let inner_end = last_row.saturating_sub(1).min(y_end.saturating_sub(1));

        if inner_start <= inner_end {
            for y in inner_start..=inner_end {
                clock.set_tile(&(y, x0).into(), &self.color)?;
                if last_col != x0 && last_col < WIDTH {
                    clock.set_tile(&(y, last_col).into(), &self.color)?;
                }
            }
        }
        Ok(())
    }
}

///Used to draw a circle on the screen starting at the given `Pos`
pub struct CircleComponent {
    pub color: Color,
    pub pos: Pos,
    pub radius: u8,
    pub outline_thickness: u8,
}

impl Component for CircleComponent {
    #[inline]
    fn name(&self) -> String {
        "circle".to_string()
    }
    fn draw(&self, clock: &mut dyn ClockConnector) -> VoidClockResult {
        self.pos.validate()?;

        //No radius or thickness no circle
        if self.radius == 0 || self.outline_thickness == 0 {
            return Ok(());
        }

        if self.outline_thickness > self.radius {
            return Err(ClockError::component_invalid_argument(
                "outline_thickness".to_string(),
                self.outline_thickness.to_string(),
                "Outline thickness of a circle component must be less than or equal to the radius!"
                    .to_string(),
            ));
        }

        let center_y = self.pos.y as f32;
        let center_x = self.pos.x as f32;

        for x in 0..64 {
            for y in 0..32 {
                let y = y as f32;
                let x = x as f32;

                let distance = ((y - center_y).powi(2) + (x - center_x).powi(2))
                    .sqrt()
                    .trunc() as u8;
                if distance >= (self.radius - self.outline_thickness) && distance < self.radius {
                    clock.set_tile(&(y as u8, x as u8).into(), &self.color)?;
                }
            }
        }

        Ok(())
    }
}
fn draw_char(
    connector: &mut dyn ClockConnector,
    y_pos: u8,
    x_pos: u8,
    font: Font,
    ch: char,
    color: Color,
) -> VoidClockResult {
    let bdf = font.get();
    let glyph = bdf
        .glyphs
        .get(&ch)
        .or_else(|| bdf.glyphs.get(&bdf.default_char))
        .unwrap_and_log("Font's default glyph is undefined in the bitmap!");

    let bytes_per_row = (bdf.width as usize).div_ceil(8);
    let row_count = glyph.len().min(bdf.height as usize);

    for row in 0..row_count {
        let row_start = row * bytes_per_row;
        let row_end = row_start + bytes_per_row;
        let row_bytes = glyph
            .get(row_start..row_end)
            .ok_or(ClockError::bdf_font_parsing(
                font.into(),
                "Failed to draw char!",
            ))?;

        let mut tile_index: u8 = 0;
        for byte in row_bytes {
            for bit in 0..8u8 {
                if tile_index >= bdf.width {
                    break;
                }
                if byte & (0x80 >> bit) != 0 {
                    connector.set_tile(
                        &(
                            (row as u8).saturating_add(y_pos),
                            tile_index.saturating_add(x_pos),
                        )
                            .into(),
                        &color,
                    )?;
                }
                tile_index += 1;
            }
        }
    }

    Ok(())
}

///Used to draw a single `char` on the screen at the given `Pos` and with the given `Color`
pub struct CharComponent {
    pub color: Color,
    pub chr: char,
    pub pos: Pos,
    pub font: Font,
}

impl Component for CharComponent {
    #[inline]
    fn name(&self) -> String {
        "char".to_string()
    }
    fn draw(&self, clock: &mut dyn ClockConnector) -> VoidClockResult {
        self.pos.validate()?;
        draw_char(
            clock, self.pos.y, self.pos.x, self.font, self.chr, self.color,
        )
    }
}

///Used to draw a `string` on the screen at the given `Pos` and with the given `Color`
pub struct TextComponent {
    pub color: Color,
    pub text: String,
    pub pos: Pos,
    pub font: Font,
}

impl Component for TextComponent {
    #[inline]
    fn name(&self) -> String {
        "text".to_string()
    }
    fn draw(&self, clock: &mut dyn ClockConnector) -> VoidClockResult {
        self.pos.validate()?;

        let width = self.font.get().width;
        let mut char_x = self.pos.x;

        for char in self.text.chars() {
            draw_char(clock, self.pos.y, char_x, self.font, char, self.color)?;
            char_x += width;
        }
        Ok(())
    }
}

///Used to draw a wrapped `string` on the screen at the given `Pos` and with the given `Color`.
///Wrapped strings will go to the next line + `line_spacing` pixels if they encounter `\n` or go over `64`px.
pub struct WrappedTextComponent {
    pub color: Color,
    pub text: String,
    pub pos: Pos,
    pub font: Font,
    pub line_spacing: i8,
}

impl Component for WrappedTextComponent {
    #[inline]
    fn name(&self) -> String {
        "wrapped_text".to_string()
    }
    fn draw(&self, clock: &mut dyn ClockConnector) -> VoidClockResult {
        self.pos.validate()?;

        let mut x = self.pos.x;
        let mut y = self.pos.y;
        let font = self.font.get();

        let min_spacing = 0.max(font.height as i8 + self.line_spacing) as u8;

        for char in self.text.chars() {
            //Reset x and increase y on newline
            if char == '\n' {
                y += min_spacing;
                x = self.pos.x;
                continue;
            }

            if font.width + x >= WIDTH {
                x = self.pos.x;
                y += min_spacing;

                // We can't draw outside y range
                if y > 31 - font.height {
                    break;
                }
            }

            draw_char(clock, y, x, self.font, char, self.color)?;
            x += font.width;
        }
        Ok(())
    }
}

///Used to draw an image the screen at the given `Pos`. The image must be loaded in the Clock's
///image store. This can be done by specifying it in the current module's image list.
pub struct ImageComponent {
    pub pos: Pos,
    pub image_name: String,
}

impl Component for ImageComponent {
    #[inline]
    fn name(&self) -> String {
        "image".to_string()
    }
    fn draw(&self, clock: &mut dyn ClockConnector) -> VoidClockResult {
        self.pos.validate()?;
        let image = clock.get_image_store().get_image(&self.image_name)?;
        let black = Color::black();

        for y in 0..image.height {
            for x in 0..image.width {
                let pixel = image
                    .pixels
                    .get((y * image.width + x) as usize)
                    .ok_or_else(|| {
                        ClockError::ppm_image_parsing(
                            &self.image_name,
                            &format!("Failed to find pixel on image y={y};x={x}"),
                        )
                    })?;
                if pixel != &black {
                    clock.set_tile(&(y + self.pos.y, x + self.pos.x).into(), pixel)?;
                }
            }
        }

        Ok(())
    }
}
