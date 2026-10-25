use std::io::Write;
use std::{
    fs::File,
    path::PathBuf,
    sync::{atomic::AtomicBool, mpsc::Sender},
};

use common::{
    clock::{color::Color, connector::ClockConnector, images::ImageStore, pos::Pos},
    utils::LogUnwrap,
};
use log::{info, warn};

use crate::test_utils::tiles_to_hex;

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

///Dumps the given `tiles` to as hex colors, creates a file at `out_path` and writes the `tiles` to
///the file.
pub fn dump_tiles_to_file(out_path: PathBuf, tiles: [[Color; 64]; 32]) {
    let tile_dump = tiles_to_hex(tiles);

    let mut dump_file = File::create(out_path).unwrap_and_log("Failed to create dump file!");
    write!(dump_file, "{}", tile_dump).unwrap_and_log("Failed to write to dump file!");

    info!("Tile dump created!");
}
