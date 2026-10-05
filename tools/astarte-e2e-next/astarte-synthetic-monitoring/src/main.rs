mod config;
pub mod interfaces;

use crate::config::Config;
use clap::Parser;

fn main() {
    let _config = Config::parse();
}
