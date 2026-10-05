use astarte_e2e::{device_room, scenarios::interfaces::device::individual_datastream::Variant};

#[tokio::test]
async fn device_datastream() -> eyre::Result<()> {
    let mut connection = device_room::Connection::new_random()?.connect().await?;

    Variant::DeviceDatastream
        .run(&mut connection.channel, &mut connection.client)
        .await
}

#[tokio::test]
async fn custom_device_datastream() -> eyre::Result<()> {
    let mut connection = device_room::Connection::new_random()?.connect().await?;

    Variant::CustomDeviceDatastream
        .run(&mut connection.channel, &mut connection.client)
        .await
}

#[tokio::test]
async fn device_datastream_overflow() -> eyre::Result<()> {
    let mut connection = device_room::Connection::new_random()?.connect().await?;

    Variant::DeviceDatastreamOverflow
        .run(&mut connection.channel, &mut connection.client)
        .await
}
