use std::path::Path;
use std::time::Duration;

use crate::amqp_trigger_consumer::AMQPTriggerConsumer;
use crate::astarte_event::{
    DataTriggerCondition, DataTriggerMatchOperator, DeviceTriggerCondition, SimpleTrigger,
    SimpleTriggerTarget, Trigger,
};
use crate::room::TransitiveTrigger;
use crate::{
    config::Config, config::DeviceConfig, device_client, interfaces::AstarteClient, room::Room,
};
use astarte_device_sdk::AstarteData::Integer;
use astarte_device_sdk::client::ClientConnection;
use astarte_device_sdk::pairing::api::{CERTIFICATE_FILE, CREDENTIAL_FILE};
use astarte_device_sdk::{
    EventLoop, pairing::api::registration::generate_random_uuid, transport::mqtt::Credential,
};

use eyre::{Context, OptionExt, ensure};
use reqwest::Url;
use tempfile::TempDir;
use tokio::sync::broadcast::Sender;
use tokio::sync::oneshot;
use tokio::task::{JoinHandle, JoinSet};
use uuid::Uuid;

/// Connection to an Astarte instance for scenarios that use both the
/// server-side room channel and a registered device.
///
/// The device can be disconnected and connected again, keeping the same store
/// (credentials secret and certificate), room and triggers.
pub struct Connection {
    config: Config,
    device_id: String,
    credential: Credential,
    pairing_url: Url,
    store: TempDir,
    pub channel: Room,
    pub client: AstarteClient,
    amqp_trigger_consumer: AMQPTriggerConsumer,
    device: Option<DeviceTask>,
    tx_cancel: Sender<()>,
    _tasks: JoinSet<eyre::Result<()>>,
}

impl Connection {
    /// Build a connection with a randomly generated device id, registered
    /// through the pairing API using the JWT as pairing token.
    pub fn from_config(config: Config) -> eyre::Result<ConnectionBuilder> {
        ConnectionBuilder::from_config(config)
    }
    /// Build a connection with a randomly generated device id, registered
    /// through the pairing API using the JWT as pairing token.
    #[cfg(feature = "clap")]
    pub fn new_random() -> eyre::Result<ConnectionBuilder> {
        ConnectionBuilder::new_random()
    }

    pub fn device_id(&self) -> &str {
        &self.device_id
    }

    /// Credentials secret of the device, either the given one or the one
    /// obtained by registering the device.
    pub async fn credentials_secret(&self) -> eyre::Result<String> {
        match &self.credential {
            Credential::Secret { credentials_secret } => Ok(credentials_secret.clone()),
            Credential::ParingToken { .. } => {
                tokio::fs::read_to_string(self.store.path().join(CREDENTIAL_FILE))
                    .await
                    .wrap_err("couldn't read the credentials secret")
            }
        }
    }

    /// Certificate currently stored by the device.
    pub async fn certificate_pem(&self) -> eyre::Result<String> {
        tokio::fs::read_to_string(self.store.path().join(CERTIFICATE_FILE))
            .await
            .wrap_err("couldn't read the certificate")
    }

    /// Pairing URL used by the next [`Connection::connect_device`].
    pub fn set_pairing_url(&mut self, pairing_url: Url) {
        self.pairing_url = pairing_url;
    }

    /// Discard the device connected events received so far.
    pub async fn purge_device_events(&mut self) -> eyre::Result<()> {
        self.amqp_trigger_consumer.purge().await
    }

    /// Connect the device and wait for the next device connected event.
    pub async fn connect_device(&mut self) -> eyre::Result<()> {
        ensure!(self.device.is_none(), "the device is already running");

        let (client, device) = spawn_device(
            &self.config,
            &self.device_id,
            self.credential.clone(),
            self.pairing_url.clone(),
            self.store.path(),
        )
        .await?;

        self.client = client;
        self.device = Some(device);

        self.wait_device_connected().await
    }

    /// Stop the device, cleanly disconnecting it if it connected.
    pub async fn disconnect_device(&mut self) -> eyre::Result<()> {
        let Some(DeviceTask {
            cancel,
            handle,
            connected,
        }) = self.device.take()
        else {
            return Ok(());
        };

        if connected {
            self.client
                .disconnect()
                .await
                .wrap_err("couldn't disconnect the device")?;
        } else {
            drop(cancel);
        }

        handle.await.wrap_err("device task panicked")?
    }

    async fn wait_device_connected(&mut self) -> eyre::Result<()> {
        self.amqp_trigger_consumer.next_device_connected().await?;

        if let Some(device) = &mut self.device {
            device.connected = true;
        }

        Ok(())
    }
}

impl Drop for Connection {
    fn drop(&mut self) {
        let _ = self.tx_cancel.send(());
    }
}

/// Event loop of the device, stopped when the cancel sender is used or dropped.
struct DeviceTask {
    cancel: oneshot::Sender<()>,
    handle: JoinHandle<eyre::Result<()>>,
    connected: bool,
}

pub struct ConnectionBuilder {
    config: Config,
    device_id: String,
    credentials_secret: Option<String>,
    receive_interface_data: bool,
    volatile_triggers: Vec<TransitiveTrigger>,
}

impl ConnectionBuilder {
    /// Build a connection with the given device id, registered through the
    /// pairing API using the JWT as pairing token.
    pub fn new(config: Config, device_id: String) -> Self {
        Self {
            config,
            device_id,
            credentials_secret: None,
            receive_interface_data: true,
            volatile_triggers: vec![],
        }
    }

    /// Build a connection with the configured device id, registered
    /// through the pairing API using the JWT as pairing token or using
    /// the given credentials secret.
    pub fn from_config(config: Config) -> eyre::Result<Self> {
        let DeviceConfig {
            device_id,
            credentials_secret,
        } = config.device.clone();

        let device_id = device_id
            .ok_or_eyre("missing device id, pass --device-id <DEVICE_ID> or set E2E_DEVICE_ID")?;
        config.astarte.jwt_required()?;

        Ok(Self {
            credentials_secret,
            ..Self::new(config, device_id)
        })
    }

    /// Build a connection with a randomly generated device id, registered
    /// through the pairing API using the JWT as pairing token.
    #[cfg(feature = "clap")]
    pub fn new_random() -> eyre::Result<Self> {
        Ok(Self::new(Config::from_env()?, generate_random_uuid()))
    }

    /// Authenticate the device with the credentials secret instead of
    /// registering it.
    pub fn credentials_secret(mut self, credentials_secret: String) -> Self {
        self.credentials_secret = Some(credentials_secret);

        self
    }

    pub async fn connect(self) -> eyre::Result<Connection> {
        let Self {
            config,
            device_id,
            credentials_secret,
            receive_interface_data,
            mut volatile_triggers,
        } = self;

        let jwt = config.astarte.jwt_required()?.to_owned();

        let credential = match credentials_secret {
            None => Credential::ParingToken { pairing_token: jwt },
            Some(secret) => Credential::Secret {
                credentials_secret: secret,
            },
        };

        let pairing_url = config.astarte.pairing_url()?;

        let store = TempDir::new().wrap_err("couldn't create the device store directory")?;

        let (tx_cancel, cancel) = tokio::sync::broadcast::channel::<()>(2);
        let mut tasks = JoinSet::<eyre::Result<()>>::new();

        let mut channel = Room::open(&config.astarte, &device_id, &mut tasks, cancel).await?;

        channel.join().await?;

        if receive_interface_data {
            volatile_triggers.push(all_interface_data_trigger(&device_id));
        }

        let exchange_device_id = device_id.replace('-', "_");
        let exchange = format!(
            "astarte_events_{}_{}_e2e",
            config.astarte.realm, exchange_device_id
        );

        // Unique across the realm, even for multiple connections of the same device
        let device_connected = format!("device-connected-{device_id}-{}", Uuid::now_v7().simple());
        let routing_key = device_connected.clone();

        let amqp_trigger_consumer =
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

        let (client, device) = spawn_device(
            &config,
            &device_id,
            credential.clone(),
            pairing_url.clone(),
            store.path(),
        )
        .await?;

        let mut connection = Connection {
            config,
            device_id,
            credential,
            pairing_url,
            store,
            channel,
            client,
            amqp_trigger_consumer,
            device: Some(device),
            tx_cancel,
            _tasks: tasks,
        };

        connection.wait_device_connected().await?;

        for trigger in volatile_triggers {
            connection.channel.watch(trigger).await?;
        }

        Ok(connection)
    }
}

async fn spawn_device(
    config: &Config,
    device_id: &str,
    credential: Credential,
    pairing_url: Url,
    store: &Path,
) -> eyre::Result<(AstarteClient, DeviceTask)> {
    let (client, connection) = device_client(
        &config.astarte.realm,
        device_id,
        credential,
        pairing_url,
        &store,
        config.astarte.ignore_ssl,
    )
    .await
    .wrap_err("couldn't connect the device")?;

    let (cancel, rx_cancel) = oneshot::channel::<()>();

    let handle = tokio::spawn(async move {
        tokio::select! {
            _ = rx_cancel => {}
            res = connection.handle_events() => res.wrap_err("handle events errored")?,
        }

        Ok(())
    });

    Ok((
        client,
        DeviceTask {
            cancel,
            handle,
            connected: false,
        },
    ))
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
