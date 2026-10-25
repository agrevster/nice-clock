use std::{
    ops::Div,
    sync::{
        atomic::{AtomicBool, Ordering},
        mpsc::Receiver,
    },
    time::Duration,
};

use common::{
    FPS,
    clock::{color::Color, pos::Pos},
    utils::LogUnwrap,
};
use log::info;
use sdl2::{
    event::Event, keyboard::Keycode, mouse::MouseButton, pixels::Color as SdlColor, rect::Rect,
    render::WindowCanvas,
};

use crate::connector::dump_tiles_to_file;

static BG_COLOR: SdlColor = SdlColor::RGB(27, 31, 25);

fn draw_tiles(tiles: &[[Color; 64]; 32], canvas: &mut WindowCanvas) {
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

fn tile_pos_for_click_pos(click: (i32, i32)) -> Pos {
    let (y, x) = click;
    Pos {
        x: (x.checked_sub_unsigned(10).unwrap().checked_div(15).unwrap()) as u8,
        y: (y.checked_sub_unsigned(10).unwrap().checked_div(15).unwrap()) as u8,
    }
}

pub fn start_simulator(rx: Receiver<[[Color; 64]; 32]>, running_flag: &AtomicBool) {
    let sleep_time = Duration::from_millis(((1.0).div(FPS as f32) * 1000.0) as u64);
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

    draw_tiles(&[[Color::black(); 64]; 32], &mut canvas);

    let mut tile_cache = [[Color::black(); 64]; 32];

    let mut event_pump = sdl
        .event_pump()
        .unwrap_and_log("Failed to get SDL event pump!");
    while running_flag.load(Ordering::Relaxed) {
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
                } => {
                    running_flag.store(false, Ordering::Relaxed);
                }
                Event::KeyDown {
                    keycode: Some(Keycode::S),
                    ..
                } => {
                    let mut filepath = std::env::current_dir().expect("Error getting the CWD!");
                    filepath.push("dump.hex");
                    dump_tiles_to_file(filepath, tile_cache);
                }
                Event::MouseButtonDown {
                    mouse_btn: MouseButton::Left,
                    x,
                    y,
                    ..
                } => {
                    let pos = tile_pos_for_click_pos((y, x));
                    info!("click: ({},{})", pos.y, pos.x);
                }
                _ => {}
            }
        }

        if let Ok(tiles) = rx.try_recv() {
            draw_tiles(&tiles, &mut canvas);
            tile_cache = tiles;
        }

        std::thread::sleep(sleep_time);
    }
}
