#![allow(dead_code)]
use std::{num::ParseIntError, path::PathBuf};

use chrono::{Duration, TimeDelta};
use common::{
    VoidClockResult,
    clock::{
        color::Color,
        components::{Component, RootComponent},
        connector::ClockConnector,
        errors::ClockError,
        module::ClockModule,
        pos::Pos,
    },
};
use log::warn;

pub struct TestingConnector {
    tiles: [[Color; 64]; 32],
    scratch: [[Color; 64]; 32],
}

impl Default for TestingConnector {
    fn default() -> Self {
        Self {
            tiles: [[Color::black(); 64]; 32],
            scratch: [[Color::black(); 64]; 32],
        }
    }
}

impl ClockConnector for TestingConnector {
    fn set_tile(&mut self, pos: &Pos, color: &Color) -> VoidClockResult {
        pos.validate()?;
        self.scratch[pos.y as usize][pos.x as usize] = *color;
        Ok(())
    }

    fn update_screen(&mut self) -> VoidClockResult {
        self.tiles = self.scratch;
        Ok(())
    }

    fn clear_screen(&mut self) -> VoidClockResult {
        self.scratch = [[Color::black(); 64]; 32];
        Ok(())
    }

    fn set_brightness(&mut self, brightness: u8) -> VoidClockResult {
        _ = brightness;
        warn!("set_brightness is not implemented in testing!");
        unimplemented!()
    }

    fn fetch_module_names(&mut self) -> Result<Vec<String>, ClockError> {
        warn!("fetch_module_names is not implemented in testing!");
        unimplemented!()
    }
}

pub fn render_to_hex(clock: &mut TestingConnector, module: ClockModule) -> String {
    module
        .root_compoent
        .render(clock, TimeDelta::seconds(1))
        .unwrap();
    tiles_to_hex(clock.tiles)
}

pub fn tiles_to_hex(tiles: [[Color; 64]; 32]) -> String {
    tiles
        .iter()
        .flat_map(|x| x.map(|y| y.to_hex()))
        .collect::<String>()
}

#[expect(clippy::needless_range_loop)]
pub fn tiles_from_hex(hex: String) -> Result<[[Color; 64]; 32], ParseIntError> {
    let mut buf = [[Color { r: 0, g: 0, b: 0 }; 64]; 32];
    for y in 0..32 {
        for x in 0..64 {
            let i = (y * 64 + x) * 7;
            buf[y][x] = Color::from_hex(&hex[i..i + 7])?
        }
    }
    Ok(buf)
}

pub fn single_component_test_module(component: Box<dyn Component>) -> ClockModule {
    ClockModule {
        name: "single_component_test_module".to_string(),
        time_limt: Duration::seconds(3),
        images_names: vec![],
        root_compoent: RootComponent::new(vec![component]),
    }
}

pub fn hex_from_file(path: PathBuf) -> String {
    std::fs::read_to_string(path).expect("Errror reading file!")
}

pub fn get_dump(name: &str) -> PathBuf {
    let mut filepath = std::env::current_dir().expect("Error getting the CWD!");
    filepath.push(PathBuf::from("tests/dumps/"));
    filepath.push(name);
    filepath
}
