use crate::{
    VoidClockResult,
    clock::{color::Color, errors::ClockError, images::ImageStore, pos::Pos},
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
    /// Used to get a mutable reference to the clock's image store.
    fn get_image_store(&mut self) -> &mut ImageStore;
}

///Used to load modules from various sources.
//TODO: Add Luau implementation and more static modules
pub mod module_loader {
    use chrono::Duration;

    use crate::{
        VoidClockResult,
        clock::{
            components::{ImageComponent, RootComponent},
            connector::ClockConnector,
            module::ClockModule,
        },
    };

    pub fn load_module(clock: &mut impl ClockConnector, module: ClockModule) -> VoidClockResult {
        let image_store = clock.get_image_store();

        image_store.clear();
        image_store.load_images_for_module(&module)?;
        module.root_compoent.render(clock, module.time_limt)
    }

    pub fn test_module() -> ClockModule {
        ClockModule {
            name: "test".to_string(),
            time_limt: Duration::seconds(5),
            images_names: vec!["tree".to_string()],
            root_compoent: RootComponent::new(vec![Box::new(ImageComponent {
                pos: (10, 5).into(),
                image_name: "tree".to_string(),
            })]),
        }
    }
}
