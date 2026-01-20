use std::time::Duration;

use crate::amqp_trigger_consumer::AMQPTriggerConsumer;
use crate::astarte_event::{
    DataTriggerCondition, DataTriggerMatchOperator, DeviceTriggerCondition, SimpleTrigger,
    SimpleTriggerTarget, Trigger,
};
use crate::room::TransitiveTrigger;
use crate::{config::Config, device_client, interfaces::AstarteClient, room::Room};
use astarte_device_sdk::AstarteData::Integer;
use astarte_device_sdk::{
    EventLoop, pairing::api::registration::generate_random_uuid, transport::mqtt::Credential,
};

#[cfg(feature = "clap")]
use clap::Parser;

use eyre::Context;
use tempfile::TempDir;
use tokio::sync::broadcast::Sender;
use tokio::task::JoinSet;

/// Connection to an Astarte instance for scenarios that use both the
/// server-side room channel and a registered device.
pub struct Connection {
    _store: TempDir,
    pub channel: Room,
    pub client: AstarteClient,
    _amqp_trigger_consumer: AMQPTriggerConsumer,
    tx_cancel: Sender<()>,
    _tasks: JoinSet<eyre::Result<()>>,
}

impl Connection {
    /// Build a connection with a randomly generated device id, registered
    /// through the pairing API using the JWT as pairing token.
    pub fn new_random() -> eyre::Result<ConnectionBuilder> {
        ConnectionBuilder::new_random()
    }
}

impl Drop for Connection {
    fn drop(&mut self) {
        let _ = self.tx_cancel.send(());
    }
}

pub struct ConnectionBuilder {
    config: Config,
    device_id: String,
    credentials_secret: Option<String>,
    receive_interface_data: bool,
    volatile_triggers: Vec<TransitiveTrigger>,
}

impl ConnectionBuilder {
    /// Build a connection with a randomly generated device id, registered
    /// through the pairing API using the JWT as pairing token.
    #[cfg(feature = "clap")]
    pub fn new_random() -> eyre::Result<Self> {
        Ok(Self {
            config: Config::try_parse()?,
            device_id: generate_random_uuid(),
            credentials_secret: None,
            receive_interface_data: true,
            volatile_triggers: vec![],
        })
    }

    pub async fn connect(self) -> eyre::Result<Connection> {
        let Self {
            config,
            device_id,
            credentials_secret,
            receive_interface_data,
            mut volatile_triggers,
        } = self;

        let credential = match credentials_secret {
            None => Credential::ParingToken {
                pairing_token: config.astarte.jwt.clone(),
            },
            Some(secret) => Credential::Secret {
                credentials_secret: secret,
            },
        };

        let store = TempDir::new().wrap_err("couldn't create the device store directory")?;

        let (tx_cancel, mut cancel) = tokio::sync::broadcast::channel::<()>(2);
        let mut tasks = JoinSet::<eyre::Result<()>>::new();

        let mut channel = Room::open(
            &config.astarte,
            &device_id,
            &mut tasks,
            cancel.resubscribe(),
        )
        .await?;

        channel.join().await?;

        if receive_interface_data {
            volatile_triggers.push(all_interface_data_trigger(&device_id));
        }

        let exchange_device_id = device_id.replace('-', "_");
        let exchange = format!(
            "astarte_events_{}_{}_e2e",
            config.astarte.realm, exchange_device_id
        );

        let device_connected = format!("device-connected-{device_id}");
        let routing_key = device_connected.clone();

        let mut amqp_trigger_consumer =
            AMQPTriggerConsumer::new(&config.amqp, &config.astarte.realm, &exchange, &routing_key)
                .await?;

        let device_connected_trigger = Trigger {
            name: device_connected,
            policy_name: None,
            action: crate::astarte_event::TriggerAction::AMQPTriggerAction {
                exchange: exchange.clone(),
                routing_key,
                message_expiration: Duration::from_secs(30),
                message_persistent: true,
                message_priority: None,
            },
            simple_triggers: vec![SimpleTrigger::DeviceTrigger {
                on: DeviceTriggerCondition::DeviceConnected,
                target: SimpleTriggerTarget::Device {
                    device_id: device_id.clone(),
                },
            }],
        };

        let api_client = config.api_client()?;

        api_client
            .install_trigger(&device_connected_trigger)
            .await?;

        let (client, connection) = device_client(
            &config.astarte.realm,
            &device_id,
            credential,
            config.astarte.pairing_url()?,
            &store,
            config.astarte.ignore_ssl,
        )
        .await
        .wrap_err("couldn't connect the device")?;

        tasks.spawn(async move {
            tokio::select! {
                res = cancel.recv() => res.wrap_err("couldn't cancel handle events")?,
                res = connection.handle_events() => res.wrap_err("handle events errored")?,
            }

            Ok(())
        });

        amqp_trigger_consumer.next_device_connected().await?;

        for trigger in volatile_triggers {
            channel.watch(trigger).await?;
        }

        Ok(Connection {
            _store: store,
            channel,
            client,
            _amqp_trigger_consumer: amqp_trigger_consumer,
            tx_cancel,
            _tasks: tasks,
        })
    }
}

fn all_interface_data_trigger(device_id: &str) -> TransitiveTrigger {
    let target = SimpleTriggerTarget::Device {
        device_id: device_id.into(),
    };

    TransitiveTrigger {
        name: format!("all-interface-trigger-{device_id}"),
        target: target.clone(),
        simple_trigger: SimpleTrigger::DataTrigger {
            on: DataTriggerCondition::IncomingData,
            target,
            interface_name: "*".into(),
            interface_major: 0,
            match_path: "/*".into(),
            value_match_operator: DataTriggerMatchOperator::AnyValue,
            known_value: Integer(0),
        },
    }
}
