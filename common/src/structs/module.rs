use chrono::Duration;

#[derive(Debug)]
pub struct ClockModule {
    ///The name of the module, used in logging
    name: String,
    ///How long the module should display on the clock
    time_limt: Duration,
    ///A vec of image names the module should load when it loads.
    images_names: Vec<String>,
}
