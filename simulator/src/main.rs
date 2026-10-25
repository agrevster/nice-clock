use std::sync::atomic::AtomicBool;
use std::{sync::mpsc::channel, thread};

use clap::Parser;
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
use simulator::cli::{Cli, Commands};
use simulator::connector::dump_tiles_to_file;
use simulator::test_utils::{TestingConnector, hex_from_file, render_to_tiles, tiles_from_hex};
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
    let running_flag = AtomicBool::new(true);

    let args = Cli::parse();

    let module = &mut test_module();

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

        match args.command.unwrap_or_default() {
            Commands::Render { hexdump } => match hexdump {
                Some(dump_path) => {
                    let mut filepath = std::env::current_dir().expect("Error getting the CWD!");
                    filepath.push(dump_path);
                    clock
                        .transmitter
                        .send(
                            tiles_from_hex(hex_from_file(filepath))
                                .expect("Error parsing tiles from hex!"),
                        )
                        .expect("Failed to send tiles to simulator window!");
                    info!("Rendering hexdump...");
                }

                None => load_module(&mut clock, module).unwrap_and_log("Error loading module!"),
            },
            Commands::Dump { out, frame } => {
                running_flag.store(false, std::sync::atomic::Ordering::Relaxed);
                dump_tiles_to_file(
                    out,
                    render_to_tiles(&mut TestingConnector::default(), module, frame.unwrap_or(0)),
                );
            }
        }

        sim_window
            .join()
            .expect("Failed to join the simulator thread into the main thread!")
    })
}
