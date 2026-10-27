use astarte_e2e::scenarios::interfaces::device::individual_datastream::IndividualDatastreamConfig;

use clap::{Parser, Subcommand};

use crate::interfaces::device::individual_datastream;

/// Name of the default subcommand, inserted into argv
/// when the user did not pass an explicit subcommand.
pub const DEFAULT_MONITOR: &str = "individual-datastream";

#[derive(Debug, Parser)]
pub struct SyntheticMonitoringConfig {
    #[command(flatten)]
    pub e2e_config: astarte_e2e::config::Config,
    #[command(subcommand)]
    pub monitor: Monitor,
}

impl SyntheticMonitoringConfig {
    pub async fn run(&self) -> eyre::Result<()> {
        let SyntheticMonitoringConfig {
            monitor,
            e2e_config,
        } = self;

        monitor.clone().run(e2e_config.clone()).await
    }

    /// Push the default subcommand in the args if no subcommand was given
    pub fn parse_with_default() -> eyre::Result<Self> {
        let args: Vec<std::ffi::OsString> = std::env::args_os().collect();
        match Self::try_parse_from(&args) {
            Ok(config) => Ok(config),
            Err(original)
                if matches!(
                    original.kind(),
                    clap::error::ErrorKind::DisplayHelp | clap::error::ErrorKind::DisplayVersion
                ) =>
            {
                Err(original.into())
            }
            Err(original) => {
                let default_intent = match args.get(1) {
                    Some(arg) => arg.to_str().is_some_and(|first| first.starts_with('-')),
                    None => true,
                };
                if !default_intent {
                    return Err(original.into());
                }
                let mut injected = Vec::with_capacity(args.len() + 1);
                injected.push(args[0].clone());
                injected.push(DEFAULT_MONITOR.into());
                injected.extend_from_slice(&args[1..]);
                // Either the default parses, or its error (in the default
                // subcommand context, e.g. a missing mandatory monitor
                // flag) is more actionable than the top-level one.
                Ok(Self::try_parse_from(&injected)?)
            }
        }
    }
}

#[derive(Debug, Subcommand, Clone)]
pub enum Monitor {
    IndividualDatastream(IndividualDatastreamConfig),
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
