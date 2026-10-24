use std::{
    cell::Cell,
    fmt::Debug,
    num::{NonZeroU8, NonZeroU32},
    sync::atomic::Ordering,
    time::{Duration, Instant},
};

use log::warn;
use macros::Animatable;

use crate::{
    FPS, HEIGHT, VoidClockResult, WIDTH,
    clock::{
        color::Color,
        connector::ClockConnector,
        errors::ClockError,
        fonts::{BDFFont, Font},
        pos::Pos,
    },
    utils::LogUnwrap,
};

///A basic trait used for all clock components. **Each component must implement this** so that it
///can be drawn on the screen.
pub trait Component {
    ///The name of the component.
    ///**It is preferred to inline this!**
    fn name(&self) -> &'static str;

    ///The function used to draw the specific component on the `clock`.
    fn draw(&self, clock: &mut dyn ClockConnector) -> VoidClockResult;
}

///Applied to all `Components` so they can be updated by an `Animation`. Not all methods have to
///update the struct for example, the `TileComponent` does not have `text` to update so the function
///is a no-op.
pub trait Animatable {
    ///Updates the component's `pos` used for `Animation`.
    fn set_pos(&mut self, pos: Pos);
    ///Updates the component's `color` used for `Animation`.
    fn set_color(&mut self, color: Color);
    ///Updates the component's `text` used for `Animation`.
    fn set_text(&mut self, text: String);
    ///Updates the component's `internal_tick` used for `Animation` on
    ///`HorizontalScrollingTextComponent`.
    fn set_internal_tick(&mut self, internal_tick: i32);
}

///Trait used for all clock components. **Each component must implement this**.
///Bundles `Animatable` and `Component` making a given complement able to be drawn as well as
///animated.
pub trait AnimatableComponent: Animatable + Component {}

///Blanket implementation so that anything that implements `Animatable` and `Component`
///implements `AnimatableComponent`.
impl<T: Component + Animatable> AnimatableComponent for T {}

///Used to represent the current state of the components in an animation.
#[derive(Debug)]
struct AnimationResolution<'a> {
    pub color: Option<Color>,
    pub pos: Option<Pos>,
    pub text: Option<&'a str>,
    pub internal_tick: Option<i32>,
}

#[derive(Debug)]
pub struct Animation {
    ///The list of ids affected by the animation
    component_ids: Vec<usize>,
    ///All the animation's keyframes
    keyframes: Vec<AnimationKeyframe>,
    ///How many animation frames that should run every clock tick (60 FPS)
    frames_per_tick: NonZeroU8,
    ///How long the animation lasts in ticks
    duration: NonZeroU32,
    ///Whether or not the animation should restart after reaching the duration
    looping: bool,
}

impl Animation {
    pub fn new(
        component_ids: Vec<usize>,
        mut keyframes: Vec<AnimationKeyframe>,
        frames_per_tick: NonZeroU8,
        duration: NonZeroU32,
        looping: bool,
    ) -> Result<Animation, ClockError> {
        if keyframes.is_empty() {
            return Err(ClockError::no_keyframes());
        }

        keyframes.sort_by_key(|k| k.tick);

        Ok(Animation {
            component_ids,
            keyframes,
            frames_per_tick,
            duration,
            looping,
        })
    }

    ///Returns the animation `tick` at the given `frame`.
    fn tick_at_frame(&self, frame: u32) -> u32 {
        let tick = frame / u32::from(self.frames_per_tick.get());
        if self.looping {
            tick % (self.duration.get() + 1)
        } else {
            tick.min(self.duration.get() + 1)
        }
    }

    ///Returns the latest version of an animation given the current `frame`.
    fn resolve(&self, frame: u32) -> AnimationResolution<'_> {
        let tick = self.tick_at_frame(frame);
        let upto = self.keyframes.partition_point(|k| k.tick <= tick);
        let seen = self.keyframes.get(..upto).unwrap_or(&[]);
        AnimationResolution {
            color: seen.iter().rev().find_map(|k| k.color),
            pos: seen.iter().rev().find_map(|k| k.pos),
            text: seen.iter().rev().find_map(|k| k.text.as_deref()),
            internal_tick: seen.iter().rev().find_map(|k| k.internal_tick),
        }
    }

    ///Applies the current keyframe at `frame` to all `components` listed as part of the animation.
    pub fn apply_state_to_components(
        &self,
        frame: u32,
        components: &mut [Box<dyn AnimatableComponent>],
    ) -> VoidClockResult {
        let r = self.resolve(frame);
        let len = components.len(); //Computed here to prevent dropping.
        for &id in &self.component_ids {
            let c = components
                .get_mut(id)
                .ok_or_else(|| ClockError::invalid_custom_animation_index(id, len))?;
            if let Some(color) = r.color {
                c.set_color(color);
            }
            if let Some(pos) = r.pos {
                c.set_pos(pos);
            }
            if let Some(text) = r.text {
                c.set_text(text.to_owned());
            }

            if let Some(internal_tick) = r.internal_tick {
                c.set_internal_tick(internal_tick);
            }
        }
        Ok(())
    }
}

#[derive(Clone, PartialEq, Debug)]
///Used to represent the state of all components listed as part of an `Animation` at a given frame.
pub struct AnimationKeyframe {
    pub tick: u32,
    pub color: Option<Color>,
    pub pos: Option<Pos>,
    pub text: Option<String>,
    pub internal_tick: Option<i32>,
}

impl AnimationKeyframe {
    ///Creates a `AnimationKeyframe` at the given `tick`.
    pub fn at(tick: u32) -> Self {
        Self {
            tick,
            color: None,
            pos: None,
            text: None,
            internal_tick: None,
        }
    }

    ///Sets the color of the given `AnimationKeyframe` to `color`
    pub fn color(mut self, color: Color) -> Self {
        self.color = Some(color);
        self
    }
    ///Sets the pos of the given `AnimationKeyframe` to `pos`
    pub fn pos(mut self, pos: Pos) -> Self {
        self.pos = Some(pos);
        self
    }
    ///Sets the text of the given `AnimationKeyframe` to `text`
    pub fn text(mut self, text: impl Into<String>) -> Self {
        self.text = Some(text.into());
        self
    }

    ///Sets the internal_tick of the given `AnimationKeyframe` to `internal_tick`
    pub fn internal_tick(mut self, internal_tick: i32) -> Self {
        self.internal_tick = Some(internal_tick);
        self
    }
}

///The starting point for a clock module.
///Run `draw` to draw the module on screen.
pub struct RootComponent {
    components: Vec<Box<dyn AnimatableComponent>>,
    animations: Vec<Animation>,
}

const SLEEP_PER_FRAME: Duration = Duration::from_micros((1_000_000.0 / FPS as f32) as u64);

impl RootComponent {
    pub fn new(
        components: Vec<Box<dyn AnimatableComponent>>,
        animations: Vec<Animation>,
    ) -> RootComponent {
        RootComponent {
            components,
            animations,
        }
    }
    ///Renders the given `frame` by applying animation state for the given `frame` and drawing all
    ///components to the `ClockConnector`.
    pub fn render_frame(&mut self, clock: &mut dyn ClockConnector, frame: u32) -> VoidClockResult {
        for animation in &self.animations {
            animation.apply_state_to_components(frame, &mut self.components)?;
        }
        clock.clear_screen()?;
        for component in &self.components {
            component.draw(clock)?;
        }
        clock.update_screen()
    }

    pub fn render(
        &mut self,
        clock: &mut dyn ClockConnector,
        time_limit: Duration,
    ) -> VoidClockResult {
        let start = Instant::now();
        let mut frame: u32 = 0;

        while clock.get_running_flag().load(Ordering::Relaxed) {
            let frame_start = Instant::now();

            self.render_frame(clock, frame)?;

            frame = frame.saturating_add(1);

            //If we have been rendering for longer than `time_limit` stop.
            if start.elapsed() >= time_limit {
                return Ok(());
            }

            //If we didn't take longer than the time required to maintain `FPS` frames per second (`SLEEP_PER_FRAME`) sleep to maintain `FPS`.
            if let Some(sleep_time) = SLEEP_PER_FRAME.checked_sub(frame_start.elapsed()) {
                std::thread::sleep(sleep_time);
            }
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

///Used to draw a single tile on the screen at the given `Pos` and with the given `Color`
#[derive(Animatable)]
pub struct TileComponent {
    pub color: Color,
    pub pos: Pos,
}

impl Component for TileComponent {
    #[inline]
    fn name(&self) -> &'static str {
        "tile"
    }
    fn draw(&self, clock: &mut dyn ClockConnector) -> VoidClockResult {
        clock.set_tile(&self.pos, &self.color)
    }
}

///Used to draw a box on the screen starting at the given `Pos`
#[derive(Animatable)]
pub struct BoxComponent {
    pub color: Color,
    pub pos: Pos,
    pub fill_inside: bool,
    pub width: u8,
    pub height: u8,
}

impl Component for BoxComponent {
    #[inline]
    fn name(&self) -> &'static str {
        "box"
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
#[derive(Animatable)]
pub struct CircleComponent {
    pub color: Color,
    pub pos: Pos,
    pub radius: u8,
    pub outline_thickness: u8,
}

impl Component for CircleComponent {
    #[inline]
    fn name(&self) -> &'static str {
        "circle"
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
#[derive(Animatable)]
pub struct CharComponent {
    pub color: Color,
    pub chr: char,
    pub pos: Pos,
    pub font: Font,
}

impl Component for CharComponent {
    #[inline]
    fn name(&self) -> &'static str {
        "char"
    }
    fn draw(&self, clock: &mut dyn ClockConnector) -> VoidClockResult {
        self.pos.validate()?;
        draw_char(
            clock, self.pos.y, self.pos.x, self.font, self.chr, self.color,
        )
    }
}

///Used to draw a `string` on the screen at the given `Pos` and with the given `Color`
#[derive(Animatable)]
pub struct TextComponent {
    pub color: Color,
    pub text: String,
    pub pos: Pos,
    pub font: Font,
}

impl Component for TextComponent {
    #[inline]
    fn name(&self) -> &'static str {
        "text"
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
#[derive(Animatable)]
pub struct WrappedTextComponent {
    pub color: Color,
    pub text: String,
    pub pos: Pos,
    pub font: Font,
    pub line_spacing: i8,
}

impl Component for WrappedTextComponent {
    #[inline]
    fn name(&self) -> &'static str {
        "wrapped_text"
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
#[derive(Animatable)]
pub struct ImageComponent {
    pub pos: Pos,
    pub image_name: String,
}

impl Component for ImageComponent {
    #[inline]
    fn name(&self) -> &'static str {
        "image"
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

///Used to draw a `string` that scrolls across on the screen starting at the given `Pos` and with the given `Color` and `Font`. The scrolling cuts off at `cutoff_x`. This uses an `Animation` to increase `internal_tick` resulting in the text scrolling across the screen from right to left.
#[derive(Animatable)]
pub struct HorizontalScrollingTextComponent {
    pub color: Color,
    pub text: String,
    pub pos: Pos,
    pub font: Font,
    pub cutoff_x: u8,
    pub internal_tick: Cell<i32>,
}

impl HorizontalScrollingTextComponent {
    #[allow(clippy::too_many_arguments)]
    fn draw_char_column_if_possible(
        &self,
        clock: &mut dyn ClockConnector,
        y_pos: u8,
        x_pos: u8,
        font: Font,
        char: char,
        column: u8,
        color: Color,
    ) -> VoidClockResult {
        if y_pos >= HEIGHT || x_pos >= WIDTH {
            return Ok(());
        }
        let bdf = font.get();
        if column >= bdf.width {
            return Ok(());
        }

        let glyph = bdf
            .glyphs
            .get(&char)
            .or_else(|| bdf.glyphs.get(&bdf.default_char))
            .unwrap_and_log("No default glyph defined for font!");

        let bytes_per_row = (bdf.width as usize).div_ceil(8);
        let byte_index = (column / 8) as usize;
        let mask = 0x80u8 >> (column % 8);

        // chunks_exact => every row_bytes.len() == bytes_per_row; no slicing panics
        for (row, row_bytes) in glyph
            .chunks_exact(bytes_per_row)
            .take(bdf.height as usize)
            .enumerate()
        {
            let Some(y) = u8::try_from(row)
                .ok()
                .and_then(|r| y_pos.checked_add(r))
                .filter(|&y| y < HEIGHT)
            else {
                break; // ran off the bottom of screen
            };

            if row_bytes[byte_index] & mask != 0 {
                clock.set_tile(&Pos::from((y, x_pos)), &color)?;
            }
        }
        Ok(())
    }
}

impl Component for HorizontalScrollingTextComponent {
    #[inline]
    fn name(&self) -> &'static str {
        "horizontal_scrolling_text"
    }

    fn draw(&self, clock: &mut dyn ClockConnector) -> VoidClockResult {
        self.pos.validate()?;
        let font = self.font.get();

        let font_width = font.width as i32;
        let start_x = self.pos.x as i32;
        let cutoff_x = self.cutoff_x as i32;
        let text_pixel_width =
            font_width.saturating_mul(i32::try_from(self.text.chars().count()).unwrap_or(i32::MAX));

        let tick = self.internal_tick.get();

        //Restart if text has made it all the way to the left
        if tick > text_pixel_width {
            return Ok(());
        }

        for (i, char) in self.text.chars().enumerate() {
            let char_start = i32::try_from(i)
                .unwrap_or(i32::MAX)
                .saturating_mul(font_width);
            for col in 0..font_width {
                let screen_x = char_start.saturating_add(col) - tick;

                if screen_x < cutoff_x {
                    continue;
                }

                if screen_x > start_x {
                    //made it to end
                    return Ok(());
                }
                self.draw_char_column_if_possible(
                    clock,
                    self.pos.y,
                    u8::try_from(screen_x).unwrap_or(WIDTH),
                    self.font,
                    char,
                    u8::try_from(col).unwrap_or(u8::MAX),
                    self.color,
                )?;
            }
        }

        Ok(())
    }
}

#[derive(Animatable)]
pub struct VerticalScrollingTextComponent {
    pub color: Color,
    pub text: String,
    pub pos: Pos,
    pub font: Font,
    pub cutoff_y: u8,
    pub internal_tick: Cell<i32>,
    pub line_spacing: i8,
}

impl VerticalScrollingTextComponent {
    #[allow(clippy::too_many_arguments)]
    fn draw_char_row_if_possible(
        &self,
        clock: &mut dyn ClockConnector,
        y_pos: u8,
        x_pos: u8,
        font: &BDFFont,
        char: char,
        row: u8,
        color: Color,
    ) -> VoidClockResult {
        if y_pos >= HEIGHT || x_pos >= WIDTH {
            return Ok(());
        }
        if row >= font.height {
            return Ok(());
        }

        let glyph = font
            .glyphs
            .get(&char)
            .or_else(|| font.glyphs.get(&font.default_char))
            .unwrap_and_log("No default glyph defined for font!");

        let bytes_per_row = (font.width as usize).div_ceil(8);
        let row_start = row as usize * bytes_per_row;

        //Skip glyphs that are invalid (smaller than the font's width)
        let Some(row_bytes) = glyph.get(row_start..row_start + bytes_per_row) else {
            warn!("Encountered invalid glyph {char}!");
            return Ok(());
        };
        for col in 0..font.width {
            let Some(x) = x_pos.checked_add(col).filter(|&x| x < WIDTH) else {
                break; // Glyph 
            };
            let Some(byte) = row_bytes.get((col / 8) as usize) else {
                break;
            };

            if byte & (0x80u8 >> (col % 8)) != 0 {
                clock.set_tile(&Pos::from((y_pos, x)), &color)?;
            }
        }

        Ok(())
    }
}

impl Component for VerticalScrollingTextComponent {
    #[inline]
    fn name(&self) -> &'static str {
        "verticial_scrolling_text"
    }

    fn draw(&self, clock: &mut dyn ClockConnector) -> VoidClockResult {
        self.pos.validate()?;
        let font = self.font.get();

        let window_top = self.cutoff_y as i32;
        let window_bottom = self.pos.y as i32;

        //Bottom should not be more than top
        if window_top >= window_bottom {
            warn!(
                "VerticalScrollingTextComponent with cutoff_y >= pos.y. This component will not be drawn!"
            );
            return Ok(());
        }

        let font_width = font.width;
        let font_height = font.height;
        let line_spacing = 0.max(font_height as i8 + self.line_spacing) as i32;
        let start_x = self.pos.x;

        let tick = self.internal_tick.get();

        let mut x = start_x;
        let mut line: i32 = 0;

        for char in self.text.chars() {
            if char == '\n' {
                line = line.saturating_add(1);
                x = start_x;
                continue;
            }

            //Wrap text if it does not fit on screen, and ensure we don't have multiple new lines
            if x > start_x && x.saturating_add(font_width) > WIDTH {
                line = line.saturating_add(1);
                x = start_x;
            }

            let char_x = x;
            x = x.saturating_add(font_width); //Move over 1 char width

            //At tick 0 line_top should be at pos.y - is below it and + is above
            let line_top = window_bottom
                .saturating_add(line.saturating_mul(line_spacing))
                .saturating_sub(tick);

            //Only rows inside the range are drawn
            let first_row = window_top.saturating_sub(line_top).max(0);
            let last_row = window_bottom
                .saturating_sub(line_top)
                .min(font_height as i32);

            for row in first_row..=last_row {
                let Ok(y) = u8::try_from(line_top.saturating_add(row)) else {
                    continue;
                };
                let Ok(row) = u8::try_from(row) else {
                    continue;
                };
                self.draw_char_row_if_possible(clock, y, char_x, font, char, row, self.color)?;
            }
        }

        Ok(())
    }
}

pub fn animate_internal_tick_component(
    id: usize,
    frames_per_tick: NonZeroU8,
    start: i32,
    duration: NonZeroU32,
    looping: bool,
) -> Animation {
    Animation {
        component_ids: vec![id],
        keyframes: (0..duration.get()).fold(Vec::new(), |mut vec, i| {
            vec.push(AnimationKeyframe::at(i).internal_tick(i32::try_from(i).unwrap_or(0) + start));
            vec
        }),
        frames_per_tick,
        duration,
        looping,
    }
}
