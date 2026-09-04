#[cfg(feature = "clap")]
use clap::{Args, ValueEnum};

use std::collections::HashMap;

use astarte_device_sdk::{AstarteData, Client};
use chrono::Utc;
use eyre::ensure;
use tracing::info;

use crate::check_astarte_value;
use crate::interfaces::{AstarteClient, InterfaceData};
use crate::room::Room;

#[derive(Debug)]
#[cfg_attr(feature = "clap", derive(Args))]
pub struct Config {
    /// Time interval between consecutive checks (in seconds).
    #[cfg_attr(feature = "clap", arg(long, env = "E2E_CHECK_INTERVAL_SECONDS"))]
    pub check_interval: u64,
    /// Variant of the check to run.
    #[cfg_attr(feature = "clap", arg(long, env = "E2E_INDIVIDUAL_DATASTREAM_VARIANT"))]
    pub individual_datastream_variant: Variant,
}

#[derive(Clone, Debug)]
#[cfg_attr(feature = "clap", derive(ValueEnum))]
pub enum Variant {
    #[cfg_attr(feature = "clap", clap(name = "default"))]
    DeviceDatastream,
    #[cfg_attr(feature = "clap", clap(name = "custom"))]
    CustomDeviceDatastream,
    #[cfg_attr(feature = "clap", clap(name = "overflow"))]
    DeviceDatastreamOverflow,
}

impl Variant {
    pub async fn run(&self, channel: &mut Room, client: &mut AstarteClient) -> eyre::Result<()> {
        match self {
            Variant::DeviceDatastream => DeviceDatastream::run(channel, client).await,
            Variant::CustomDeviceDatastream => CustomDeviceDatastream::run(channel, client).await,
            Variant::DeviceDatastreamOverflow => {
                DeviceDatastreamOverflow::run(channel, client).await
            }
        }
    }
}

pub trait CheckRunner: Sized {
    fn run(
        channel: &mut Room,
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
    async fn run(channel: &mut Room, client: &mut AstarteClient) -> eyre::Result<()> {
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
    async fn run(channel: &mut Room, client: &mut AstarteClient) -> eyre::Result<()> {
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
    async fn run(channel: &mut Room, client: &mut AstarteClient) -> eyre::Result<()> {
        validate_individual::<Self>(channel, client).await
    }
}

pub async fn validate_individual<T>(
    channel: &mut Room,
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

        let incoming = channel.next_data_event().await?;

        ensure!(incoming.interface() == interface_name.as_str());
        ensure!(incoming.path() == data_path.as_str());
        check_astarte_value(&data, &incoming.value()?)?;

        info!(interface = interface_name, path = data_path, "validated")
    }

    Ok(())
}

pub async fn check(channel: &mut Room, client: &mut AstarteClient) -> eyre::Result<()> {
    validate_individual::<DeviceDatastream>(channel, client).await?;
    validate_individual::<DeviceDatastreamOverflow>(channel, client).await?;
    validate_individual::<CustomDeviceDatastream>(channel, client).await?;

    Ok(())
}
