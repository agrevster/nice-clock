use std::{
    ops::Div,
    sync::mpsc::{Receiver, Sender, channel},
    thread,
    time::Duration,
};

use common::{
    FPS,
    structs::{
        color::Color,
        connector::{
            ClockConnector,
            module_loader::{load_module, test_module},
        },
        pos::Pos,
    },
    utils::LogUnwrap,
};
use log::{info, warn};
use sdl2::{
    event::Event, keyboard::Keycode, pixels::Color as SdlColor, rect::Rect, render::WindowCanvas,
};
use simplelog::{ConfigBuilder, TermLogger, format_description};

static BG_COLOR: SdlColor = SdlColor::RGB(27, 31, 25);

struct SimulatorConnector {
    scratch: [[Color; 64]; 32],
    transmitter: Sender<[[Color; 64]; 32]>,
}

impl ClockConnector for SimulatorConnector {
    fn set_tile(self: &mut Self, pos: &Pos, color: &Color) -> common::VoidClockResult {
        let pos = pos.validate()?;
        self.scratch[pos.y as usize][pos.x as usize] = *color;
        Ok(())
    }

    fn update_screen(self: &mut Self) -> common::VoidClockResult {
        // Ignore error because as eventually the thread will close once the sdl thread closes.
        let _ = self.transmitter.send(self.scratch);
        Ok(())
    }

    fn clear_screen(self: &mut Self) -> common::VoidClockResult {
        self.scratch = [[Color::black(); 64]; 32];
        Ok(())
    }

    fn set_brightness(self: &mut Self, brightness: u8) -> common::VoidClockResult {
        _ = brightness;
        warn!("set_brightness is not implemented on the simulator!");
        unimplemented!()
    }

    fn fetch_module_names(
        self: &mut Self,
    ) -> Result<Vec<String>, common::structs::errors::ClockError> {
        warn!("fetch_module_names is not implemented on the simulator!");
        unimplemented!()
    }
}

fn draw_tiles(tiles: [[Color; 64]; 32], canvas: &mut WindowCanvas) {
    canvas.set_draw_color(BG_COLOR);
    canvas.clear();
    tiles.iter().enumerate().for_each(|(x, col)| {
        col.iter().enumerate().for_each(|(y, color)| {
            canvas.set_draw_color(SdlColor::RGB(color.r, color.g, color.b));
            canvas
                .fill_rect(Rect::new(
                    (10 + y * 15) as i32,
                    (10 + x * 15) as i32,
                    10,
                    10,
                ))
                .unwrap_and_log("Error drawing rect!")
        });
    });
    canvas.present();
}

fn start_simulator(rx: Receiver<[[Color; 64]; 32]>) {
    let sleep_time = Duration::from_millis(((1 as f32).div(FPS as f32) * 1000.0) as u64);
    let sdl = sdl2::init().unwrap_and_log("Failed to create SDL session for simulator!");
    let video = sdl
        .video()
        .unwrap_and_log("Failed to create SDL video session for simulator!");

    let mut window = video
        .window("nice-clock: simulator", 975, 493)
        .position_centered()
        .build()
        .unwrap_and_log("Failed to create SDL window!");

    window.set_resizable(false);

    let mut canvas = window
        .into_canvas()
        .build()
        .unwrap_and_log("Failed to create SDL canvas!");

    draw_tiles([[Color::black(); 64]; 32], &mut canvas);

    let mut event_pump = sdl
        .event_pump()
        .unwrap_and_log("Failed to get SDL event pump!");
    'run: loop {
        for event in event_pump.poll_iter() {
            match event {
                Event::Quit { .. }
                | Event::KeyDown {
                    keycode: Some(Keycode::Q),
                    ..
                }
                | Event::KeyDown {
                    keycode: Some(Keycode::Escape),
                    ..
                } => break 'run,
                _ => {}
            }
        }

        if let Ok(tiles) = rx.try_recv() {
            draw_tiles(tiles, &mut canvas);
        }

        std::thread::sleep(sleep_time);
    }
}

fn main() {
    let log_config = ConfigBuilder::default()
        .set_location_level(log::LevelFilter::Debug)
        .set_time_level(log::LevelFilter::Info)
        .set_target_level(log::LevelFilter::Info)
        .set_time_format_custom(format_description!(
            "[year]-[month]-[day] [hour]:[minute]:[second]"
        ))
        .build();

    TermLogger::init(
        log::LevelFilter::Info,
        log_config,
        simplelog::TerminalMode::Mixed,
        simplelog::ColorChoice::Auto,
    )
    .expect("Failed to start logger!");

    let (tx, rx) = channel::<[[Color; 64]; 32]>();

    let mut clock = SimulatorConnector {
        scratch: [[Color::black(); 64]; 32],
        transmitter: tx,
    };

    thread::scope(|scope| {
        let sim_window = scope.spawn(|| {
            info!("Starting clock simulator...");
            start_simulator(rx);
        });

        load_module(&mut clock, test_module()).unwrap_and_log("Error loading module!");

        sim_window
            .join()
            .expect("Failed to join the simulator thread into the main thread!")
    })
}
