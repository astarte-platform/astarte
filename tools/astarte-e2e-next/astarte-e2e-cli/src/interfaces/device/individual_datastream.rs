// This file is part of Astarte.
//
// Copyright 2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

use std::time::Duration;

use astarte_e2e::{
    interfaces::{
        AstarteClient,
        device::individual_datastream::{
            CheckRunner, CustomDeviceDatastream, DeviceDatastream, DeviceDatastreamOverflow,
        },
    },
    transport::phoenix_channel::PhoenixChannel,
};
use clap::{Args, ValueEnum};
use tokio::time::sleep;

#[derive(Debug, Args)]
pub struct Config {
    /// Time interval between consecutive checks (in seconds).
    #[arg(long, env = "E2E_CHECK_INTERVAL_SECONDS")]
    pub(crate) check_interval: u64,
    /// Variant of the check to run.
    #[arg(long, env = "E2E_INDIVIDUAL_DATASTREAM_VARIANT")]
    pub(crate) individual_datastream_variant: Variant,
}

#[derive(Clone, Debug, ValueEnum)]
pub enum Variant {
    #[clap(name = "default")]
    DeviceDatastream,
    #[clap(name = "custom")]
    CustomDeviceDatastream,
    #[clap(name = "overflow")]
    DeviceDatastreamOverflow,
}

impl Variant {
    pub async fn run(
        &self,
        channel: &mut PhoenixChannel,
        client: &mut AstarteClient,
    ) -> eyre::Result<()> {
        match self {
            Variant::DeviceDatastream => DeviceDatastream::run(channel, client).await,
            Variant::CustomDeviceDatastream => CustomDeviceDatastream::run(channel, client).await,
            Variant::DeviceDatastreamOverflow => {
                DeviceDatastreamOverflow::run(channel, client).await
            }
        }
    }
}

pub async fn run(
    config: &Config,
    mut channel: &mut PhoenixChannel,
    mut client: &mut AstarteClient,
) -> eyre::Result<()> {
    loop {
        config
            .individual_datastream_variant
            .run(&mut channel, &mut client)
            .await?;
        sleep(Duration::from_secs(config.check_interval)).await;
    }
}

#[cfg(test)]
pub mod utils {
    use clap::Parser;

    type BaseConfig = super::Config;

    #[derive(Debug, Parser)]
    pub(crate) struct Config {
        #[command(flatten)]
        pub config: BaseConfig,
    }
}

#[cfg(test)]
mod test {
    use astarte_e2e::interfaces::device::individual_datastream::{
        DeviceDatastream, validate_individual,
    };

    use crate::utils::connect_to_astarte;

    #[tokio::test]
    pub async fn device_datastream_check() -> eyre::Result<()> {
        let mut state = connect_to_astarte().await?;
        validate_individual::<DeviceDatastream>(&mut state.channel, &mut state.client).await
    }
}
