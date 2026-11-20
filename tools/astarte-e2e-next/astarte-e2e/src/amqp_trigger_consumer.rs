use std::time::Duration;

use eyre::eyre;
use lapin::{
    Channel, Connection, ConnectionProperties, Consumer,
    options::{
        BasicAckOptions, BasicConsumeOptions, ExchangeDeclareOptions, QueueBindOptions,
        QueueDeclareOptions, QueuePurgeOptions,
    },
    types::FieldTable,
};
use prost::Message;
use tokio_stream::StreamExt;

use crate::{
    astarte_event::{DeviceConnectedEvent, Event, SimpleEvent},
    config::AmqpConfig,
};

/// How long the consumer must stay idle for a purge to be considered complete
const PURGE_IDLE: Duration = Duration::from_millis(500);

pub struct AMQPTriggerConsumer {
    _conn: Connection,
    channel: Channel,
    queue: String,
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
            channel,
            queue: queue_name.to_string(),
            consumer,
        })
    }

    /// Discard all the events received so far.
    ///
    /// Without a prefetch limit the messages are pushed to the consumer as soon
    /// as they are published, so purging the queue is not enough: the ones
    /// already delivered are acked and dropped until the consumer is idle.
    pub async fn purge(&mut self) -> eyre::Result<()> {
        self.channel
            .queue_purge(self.queue.as_str().into(), QueuePurgeOptions::default())
            .await?;

        while let Ok(delivery) = tokio::time::timeout(PURGE_IDLE, self.consumer.next()).await {
            let delivery = delivery.ok_or_else(|| eyre!("AMQP consumer stream closed"))??;

            delivery.ack(BasicAckOptions::default()).await?;
        }

        Ok(())
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
