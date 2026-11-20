#[cfg(feature = "clap")]
use clap::ValueEnum;

use std::time::Duration;

use astarte_device_sdk::pairing::api::registration::generate_random_uuid;
use eyre::{bail, ensure};
use tracing::info;

use crate::astarte::ApiClient;
use crate::config::Config;
use crate::device_room::{Connection, ConnectionBuilder};
use crate::mock_pairing::MockPairing;
use crate::scenarios::interfaces::device::individual_datastream::{
    DeviceDatastream, validate_individual,
};

/// Time after which a device that didn't connect is considered blocked.
const BLOCKED_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Clone, Debug)]
#[cfg_attr(feature = "clap", derive(ValueEnum))]
pub enum Variant {
    /// The broker refuses a certificate superseded by a new one.
    #[cfg_attr(feature = "clap", clap(name = "superseded-broker"))]
    SupersededBroker,
    /// Pairing reports a certificate superseded by a new one as invalid.
    #[cfg_attr(feature = "clap", clap(name = "superseded-pairing"))]
    SupersededPairing,
}

impl Variant {
    /// A device obtains a first certificate, then a second one from a new
    /// store, and must only be able to use the second one.
    pub async fn run(&self, config: Config) -> eyre::Result<()> {
        let mut first = ConnectionBuilder::new(config.clone(), generate_random_uuid())
            .connect()
            .await?;

        validate_individual::<DeviceDatastream>(&mut first.channel, &mut first.client).await?;
        first.disconnect_device().await?;

        let first_certificate = first.certificate_pem().await?;
        let credentials_secret = first.credentials_secret().await?;
        let device_id = first.device_id().to_string();

        info!(device_id, "first certificate obtained");

        let mut second = ConnectionBuilder::new(config.clone(), device_id.clone())
            .credentials_secret(credentials_secret.clone())
            .connect()
            .await?;

        let second_certificate = second.certificate_pem().await?;
        ensure!(
            first_certificate != second_certificate,
            "the device reused the first certificate"
        );

        validate_individual::<DeviceDatastream>(&mut second.channel, &mut second.client).await?;
        second.disconnect_device().await?;

        info!(device_id, "second certificate obtained");

        let api = ApiClient {
            device_id: device_id.clone(),
            ..config.api_client()?
        };

        match self {
            Variant::SupersededBroker => {
                check_broker(&api, &credentials_secret, &mut first, &first_certificate).await?
            }
            Variant::SupersededPairing => {
                check_pairing(
                    &api,
                    &credentials_secret,
                    &first_certificate,
                    &second_certificate,
                )
                .await?
            }
        }

        // The other connection of the device also publishes on this queue
        second.purge_device_events().await?;
        second.connect_device().await?;

        ensure!(
            second.certificate_pem().await? == second_certificate,
            "the device replaced the second certificate"
        );

        validate_individual::<DeviceDatastream>(&mut second.channel, &mut second.client).await?;
        second.disconnect_device().await
    }
}

/// Connect the device with the superseded certificate, faking its validity
/// to the device so that it doesn't replace it.
async fn check_broker(
    api: &ApiClient,
    credentials_secret: &str,
    connection: &mut Connection,
    certificate: &str,
) -> eyre::Result<()> {
    let info = api.pairing_device_info(credentials_secret).await?;
    let mock_pairing = MockPairing::start(&api.realm, &api.device_id, &info).await;

    connection.set_pairing_url(mock_pairing.url()?);

    // The other connection of the device also publishes on this queue
    connection.purge_device_events().await?;

    let res = tokio::time::timeout(BLOCKED_TIMEOUT, connection.connect_device()).await;
    connection.disconnect_device().await?;

    ensure!(
        connection.certificate_pem().await? == certificate,
        "the device replaced the superseded certificate"
    );

    match res {
        Ok(Ok(())) => bail!("the device connected with the superseded certificate"),
        Ok(Err(err)) => Err(err),
        Err(_) => {
            info!("connection with the superseded certificate blocked");

            Ok(())
        }
    }
}

async fn check_pairing(
    api: &ApiClient,
    credentials_secret: &str,
    superseded: &str,
    current: &str,
) -> eyre::Result<()> {
    let status = api
        .verify_certificate(credentials_secret, superseded)
        .await?;
    info!(cause = ?status.cause, "superseded certificate verified");
    ensure!(
        !status.valid,
        "pairing reported the superseded certificate as valid"
    );

    let status = api.verify_certificate(credentials_secret, current).await?;
    ensure!(
        status.valid,
        "pairing reported the current certificate as invalid: {:?}",
        status.cause
    );

    Ok(())
}
