use eyre::eyre;
use lapin::{
    Channel, Connection, ConnectionProperties, Consumer,
    options::{
        BasicAckOptions, BasicConsumeOptions, ExchangeDeclareOptions, QueueBindOptions,
        QueueDeclareOptions,
    },
    types::FieldTable,
};
use prost::Message;
use tokio_stream::StreamExt;

use crate::{
    astarte_event::{DeviceConnectedEvent, Event, SimpleEvent},
    config::AmqpConfig,
};

pub struct AMQPTriggerConsumer {
    _conn: Connection,
    _channel: Channel,
    consumer: Consumer,
}

impl AMQPTriggerConsumer {
    pub async fn new(
        amqp_config: &AmqpConfig,
        realm: &str,
        exchange: &str,
        routing_key: &str,
    ) -> eyre::Result<Self> {
        let queue_name = routing_key;
        let uri = format!("{}/_{}", amqp_config.uri(), realm);
        let conn = Connection::connect(&uri, ConnectionProperties::default()).await?;
        let channel = conn.create_channel().await?;

        channel
            .exchange_declare(
                exchange.into(),
                lapin::ExchangeKind::Direct,
                ExchangeDeclareOptions {
                    durable: true,
                    ..ExchangeDeclareOptions::default()
                },
                FieldTable::default(),
            )
            .await?;

        channel
            .queue_declare(
                queue_name.into(),
                QueueDeclareOptions::durable(),
                FieldTable::default(),
            )
            .await?;

        channel
            .queue_bind(
                queue_name.into(),
                exchange.into(),
                routing_key.into(),
                QueueBindOptions::default(),
                FieldTable::default(),
            )
            .await?;

        let consumer = channel
            .basic_consume(
                queue_name.into(),
                "".into(),
                BasicConsumeOptions::default(),
                FieldTable::default(),
            )
            .await?;

        Ok(Self {
            _conn: conn,
            _channel: channel,
            consumer,
        })
    }

    pub async fn next_device_connected(&mut self) -> eyre::Result<DeviceConnectedEvent> {
        loop {
            let delivery = self
                .consumer
                .next()
                .await
                .ok_or_else(|| eyre!("AMQP consumer stream closed"))??;

            let event: SimpleEvent = SimpleEvent::decode(delivery.data.as_slice())?;

            delivery.ack(BasicAckOptions::default()).await?;

            if let Some(Event::DeviceConnectedEvent(device_connected)) = event.event {
                return Ok(device_connected);
            }
        }
    }
}
