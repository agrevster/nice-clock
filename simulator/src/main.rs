use std::sync::atomic::AtomicBool;
use std::{sync::mpsc::channel, thread};

use common::{
    clock::{
        color::Color,
        connector::module_loader::{load_module, test_module},
        fonts::Font,
        images::ImageStore,
    },
    utils::LogUnwrap,
};
use log::info;
use simplelog::{ConfigBuilder, TermLogger, format_description};
use simulator::test_utils::{hex_from_file, tiles_from_hex};
use simulator::{connector::SimulatorConnector, window};

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

    Font::load_fonts().unwrap_and_log("Error loading fonts!");
    let (tx, rx) = channel::<[[Color; 64]; 32]>();

    let args = std::env::args().collect::<Vec<String>>();

    let hexdump_view = args.len() > 1;
    let hexdump_file = args.last();
    let running_flag = AtomicBool::new(true);

    let mut clock = SimulatorConnector {
        running_flag: &running_flag,
        scratch: [[Color::black(); 64]; 32],
        transmitter: tx,
        image_store: ImageStore::default(),
    };

    thread::scope(|scope| {
        let sim_window = scope.spawn(|| {
            info!("Starting clock simulator...");
            window::start_simulator(rx, &running_flag);
        });

        if !hexdump_view {
            load_module(&mut clock, &mut test_module()).unwrap_and_log("Error loading module!");
        } else {
            let mut filepath = std::env::current_dir().expect("Error getting the CWD!");
            filepath.push(
                hexdump_file
                    .expect("Failed to get hexdump file from args. Might be a parsing issue..."),
            );
            clock
                .transmitter
                .send(
                    tiles_from_hex(hex_from_file(filepath)).expect("Error parsing tiles from hex!"),
                )
                .expect("Failed to send tiles to simulator window!");
            info!("Rendering hexdump...");
        }

        sim_window
            .join()
            .expect("Failed to join the simulator thread into the main thread!")
    })
}
