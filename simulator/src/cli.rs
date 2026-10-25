use std::path::PathBuf;

use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(version, about)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Option<Commands>,
}

#[derive(Subcommand)]
pub enum Commands {
    ///Creates a window displaying the current module.
    ///Type `q` to quit, `s` to save as a hexdump and click on a tile to log the position.
    Render {
        ///The path to the hexdump to render.
        #[arg(short = 'i', long)]
        hexdump: Option<PathBuf>,
    },
    ///Creates a hex dump of the given module
    Dump {
        ///The path to the outputted hex dump.
        #[arg(short, long)]
        out: PathBuf,
        ///The animation frame number to dump.
        #[arg(long)]
        frame: Option<u32>,
    },
}

///Default to render without hexdump
impl Default for Commands {
    fn default() -> Self {
        Commands::Render { hexdump: None }
    }
}
