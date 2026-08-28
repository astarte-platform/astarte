use astarte_e2e::scenarios;

use clap::{Parser, Subcommand};

use crate::interfaces::device::individual_datastream;

#[derive(Debug, Parser)]
pub struct Config {
    #[command(subcommand)]
    pub monitor: Monitor,
    #[command(flatten)]
    pub e2e_config: astarte_e2e::config::Config,
}

impl Config {
    pub async fn run(&self) -> eyre::Result<()> {
        let Config {
            monitor,
            e2e_config,
        } = self;

        monitor.run(e2e_config.clone()).await
    }
}

#[derive(Debug, Subcommand)]
pub enum Monitor {
    IndividualDatastream(scenarios::interfaces::device::individual_datastream::Config),
}

impl Monitor {
    pub async fn run(&self, e2e_config: astarte_e2e::config::Config) -> eyre::Result<()> {
        match self {
            Self::IndividualDatastream(check_config) => {
                individual_datastream::run(check_config, e2e_config).await
            }
        }
    }
}
