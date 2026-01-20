use astarte_e2e::scenarios;

use clap::{Parser, Subcommand};

#[derive(Debug, Parser)]
pub struct Config {
    #[command(subcommand)]
    pub monitor: Monitor,
    #[command(flatten)]
    pub e2e_config: astarte_e2e::config::Config,
}

#[derive(Debug, Subcommand)]
pub enum Monitor {
    IndividualDatastream(scenarios::interfaces::device::individual_datastream::Config),
}
