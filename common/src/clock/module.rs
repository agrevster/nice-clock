use std::time::Duration;

use crate::clock::components::RootComponent;

#[derive(Debug)]
pub struct ClockModule {
    ///The name of the module, used in logging
    pub name: String,
    ///How long the module should display on the clock
    pub time_limt: Duration,
    ///A vec of image names the module should load when it loads.
    pub images_names: Vec<String>,
    ///The module's `component`s
    pub root_compoent: RootComponent,
}
