use std::time::Duration;

use astarte_e2e::{
    interfaces::AstarteClient, room::Room,
    scenarios::interfaces::device::individual_datastream::Config,
};
use tokio::time::sleep;

pub async fn run(
    config: &Config,
    channel: &mut Room,
    client: &mut AstarteClient,
) -> eyre::Result<()> {
    loop {
        config
            .individual_datastream_variant
            .run(channel, client)
            .await?;
        sleep(Duration::from_secs(config.check_interval)).await;
    }
}
