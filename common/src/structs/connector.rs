use crate::{
    VoidClockResult,
    structs::{color::Color, errors::ClockError, pos::Pos},
};

///Required to create a nice-clock connector.
pub trait ClockConnector {
    /// Used to set the `color` of a tile at the given `Pos`
    fn set_tile(&mut self, pos: &Pos, color: &Color) -> VoidClockResult;
    ///Updates the screen to show the most recent changes in tiles.
    fn update_screen(&mut self) -> VoidClockResult;
    ///Clears the screen
    fn clear_screen(&mut self) -> VoidClockResult;
    ///Sets the brightness of the display to the given `brightness`.
    ///**Values must be between 0 and 100 inclusive!**
    fn set_brightness(&mut self, brightness: u8) -> VoidClockResult;
    /// Used to get the module names to load for the clock.
    fn fetch_module_names(&mut self) -> Result<Vec<String>, ClockError>;
}

///Used to load modules from various sources.
//TODO: Add Luau implementation and more static modules
pub mod module_loader {
    use chrono::Duration;

    use crate::{
        VoidClockResult,
        structs::{
            color::Color,
            components::{RootComponent, WrappedTextComponent},
            connector::ClockConnector,
            fonts::Font,
            module::ClockModule,
        },
    };

    pub fn load_module(clock: &mut impl ClockConnector, module: ClockModule) -> VoidClockResult {
        module.root_compoent.render(clock, module.time_limt)
    }

    pub fn test_module() -> ClockModule {
        ClockModule {
            name: "test".to_string(),
            time_limt: Duration::seconds(5),
            images_names: vec![],
            root_compoent: RootComponent::new(vec![Box::new(WrappedTextComponent {
                pos: (0, 10).into(),
                color: Color::green(),
                text: "1:The left\n2:right\n3:Center".to_string(),
                font: Font::Font5x8_2,
                line_spacing: -5,
            })]),
        }
    }
}
