use std::time::Duration;

use astarte_e2e::{
    device_room::Connection,
    interfaces::AstarteClient,
    room::Room,
    scenarios::interfaces::device::individual_datastream::{
        Config,
        Repetitions::{Finite, Infinity},
        RonundTripStrategy, Variant,
    },
};
use tokio::time::sleep;

type E2EConfig = astarte_e2e::config::Config;

pub async fn run(config: &Config, e2e_config: E2EConfig) -> eyre::Result<()> {
    match config.roudtrip_strategy {
        RonundTripStrategy::VolatileTrigger => run_volatile(config, e2e_config).await,
        _ => todo!(),
    }
}

async fn run_volatile(config: &Config, e2e_config: E2EConfig) -> eyre::Result<()> {
    let mut device_room = Connection::from_config(e2e_config)?.connect().await?;
    let Connection {
        channel, client, ..
    } = &mut device_room;
    let variant = &config.individual_datastream_variant;
    let check_interval = Duration::from_secs(config.check_interval);

    match config.repetitions {
        Infinity => run_volatile_uncapped(variant, channel, client, check_interval).await?,
        Finite(repetitions) => {
            run_volatile_finite(repetitions, variant, channel, client, check_interval).await?;
        }
    }

    loop {
        config
            .individual_datastream_variant
            .run(channel, client)
            .await?;
        sleep(Duration::from_secs(config.check_interval)).await;
    }
}

async fn run_volatile_uncapped(
    variant: &Variant,
    channel: &mut Room,
    client: &mut AstarteClient,
    check_interval: Duration,
) -> eyre::Result<()> {
    loop {
        run_volatile_once(variant, channel, client, check_interval).await?;
    }
}

async fn run_volatile_finite(
    repetitions: u32,
    variant: &Variant,
    channel: &mut Room,
    client: &mut AstarteClient,
    check_interval: Duration,
) -> eyre::Result<()> {
    // SAFETY: repetitions is >= 1
    let all_but_one_repetitions = repetitions - 1;
    for _ in 0..all_but_one_repetitions {
        run_volatile_once(variant, channel, client, check_interval).await?;
    }
    // The last repetitions does not need to sleep afterwards
    variant.run(channel, client).await?;

    Ok(())
}

async fn run_volatile_once(
    variant: &Variant,
    channel: &mut Room,
    client: &mut AstarteClient,
    check_interval: Duration,
) -> eyre::Result<()> {
    variant.run(channel, client).await?;
    sleep(check_interval).await;
    Ok(())
}
