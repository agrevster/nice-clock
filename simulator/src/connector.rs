use std::sync::{atomic::AtomicBool, mpsc::Sender};

use common::clock::{color::Color, connector::ClockConnector, images::ImageStore, pos::Pos};
use log::warn;

pub struct SimulatorConnector<'a> {
    pub transmitter: Sender<[[Color; 64]; 32]>,
    pub scratch: [[Color; 64]; 32],
    pub image_store: ImageStore,
    pub running_flag: &'a AtomicBool,
}

impl<'a> ClockConnector for SimulatorConnector<'a> {
    fn set_tile(&mut self, pos: &Pos, color: &Color) -> common::VoidClockResult {
        let pos = pos.validate()?;
        self.scratch[pos.y as usize][pos.x as usize] = *color;
        Ok(())
    }

    fn update_screen(&mut self) -> common::VoidClockResult {
        // Ignore error because as eventually the thread will close once the sdl thread closes.
        let _ = self.transmitter.send(self.scratch);
        Ok(())
    }

    fn clear_screen(&mut self) -> common::VoidClockResult {
        self.scratch = [[Color::black(); 64]; 32];
        Ok(())
    }

    fn set_brightness(&mut self, brightness: u8) -> common::VoidClockResult {
        _ = brightness;
        warn!("set_brightness is not implemented on the simulator!");
        unimplemented!()
    }

    fn fetch_module_names(&mut self) -> Result<Vec<String>, common::clock::errors::ClockError> {
        warn!("fetch_module_names is not implemented on the simulator!");
        unimplemented!()
    }

    fn get_image_store(&mut self) -> &mut ImageStore {
        &mut self.image_store
    }

    fn get_running_flag(&self) -> &AtomicBool {
        self.running_flag
    }
}
