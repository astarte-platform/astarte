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

use std::collections::HashMap;

use astarte_device_sdk::{AstarteData, Client};
use chrono::Utc;
use eyre::ensure;
use tracing::{info, instrument};

use crate::astarte_event::IncomingData;
use crate::check_astarte_value;
use crate::interfaces::{AstarteClient, InterfaceData};
use crate::transport::phoenix_channel::PhoenixChannel;

pub trait CheckRunner: Sized {
    fn run(
        channel: &mut PhoenixChannel,
        client: &mut AstarteClient,
    ) -> impl Future<Output = eyre::Result<()>> + Send;
}

#[derive(Debug)]
pub struct DeviceDatastream {}

impl InterfaceData for DeviceDatastream {
    fn interface() -> String {
        "org.astarte-platform.e2e.DeviceDatastream".to_string()
    }
}

impl CheckRunner for DeviceDatastream {
    async fn run(channel: &mut PhoenixChannel, client: &mut AstarteClient) -> eyre::Result<()> {
        validate_individual::<Self>(channel, client).await
    }
}

/// Send a value with a long integer > 2^53 + 1
#[derive(Debug)]
pub struct DeviceDatastreamOverflow {}

impl InterfaceData for DeviceDatastreamOverflow {
    fn interface() -> String {
        "org.astarte-platform.e2e.DeviceDatastream".to_string()
    }

    fn data() -> eyre::Result<HashMap<String, AstarteData>> {
        let mut data = HashMap::with_capacity(2);

        data.insert(
            "/longinteger_endpoint".to_string(),
            AstarteData::LongInteger(2i64.pow(55)),
        );
        data.insert(
            "/longintegerarray_endpoint".to_string(),
            AstarteData::LongIntegerArray(vec![2i64.pow(55); 4]),
        );

        Ok(data)
    }
}

impl CheckRunner for DeviceDatastreamOverflow {
    async fn run(channel: &mut PhoenixChannel, client: &mut AstarteClient) -> eyre::Result<()> {
        validate_individual::<Self>(channel, client).await
    }
}

/// Test retention and reliability combinations
#[derive(Debug)]
pub struct CustomDeviceDatastream {}

impl InterfaceData for CustomDeviceDatastream {
    fn interface() -> String {
        "org.astarte-platform.e2e.CustomDeviceDatastream".to_string()
    }

    fn data() -> eyre::Result<HashMap<String, AstarteData>> {
        let data = HashMap::from_iter(
            [
                ("/volatileUnreliable", AstarteData::LongInteger(42)),
                ("/volatileGuaranteed", AstarteData::Boolean(false)),
                ("/volatileUnique", AstarteData::try_from(35.2)?),
                ("/storedUnreliable", AstarteData::LongInteger(42)),
                ("/storedGuaranteed", AstarteData::Boolean(false)),
                ("/storedUnique", AstarteData::try_from(35.2)?),
            ]
            .map(|(k, v)| (k.to_string(), v)),
        );

        Ok(data)
    }
}

impl CheckRunner for CustomDeviceDatastream {
    async fn run(channel: &mut PhoenixChannel, client: &mut AstarteClient) -> eyre::Result<()> {
        validate_individual::<Self>(channel, client).await
    }
}

pub async fn validate_individual<T>(
    channel: &mut PhoenixChannel,
    client: &mut AstarteClient,
) -> eyre::Result<()>
where
    T: InterfaceData,
{
    let data = T::data()?;
    let interface_name = T::interface();

    for (data_path, data) in data {
        client
            .send_individual_with_timestamp(&interface_name, &data_path, data.clone(), Utc::now())
            .await?;

        dbg!(&channel);

        let IncomingData {
            interface,
            path,
            value,
        } = channel.next_data_event().await?;

        ensure!(interface == interface_name);
        ensure!(path == data_path);
        check_astarte_value(&data, &value)?;

        info!(interface, path, "validated")
    }

    Ok(())
}

#[instrument(skip_all)]
pub async fn check(channel: &mut PhoenixChannel, client: &mut AstarteClient) -> eyre::Result<()> {
    validate_individual::<DeviceDatastream>(channel, client).await?;
    validate_individual::<DeviceDatastreamOverflow>(channel, client).await?;
    validate_individual::<CustomDeviceDatastream>(channel, client).await?;

    Ok(())
}

// #[cfg(test)]
// mod test {

//     #[test]
//     pub async fn volatile_check() -> eyre::Result<()> {
//         validate_individual::<DeviceDatastream>(channel, client).await?;
//         Ok(())
//     }
// }
