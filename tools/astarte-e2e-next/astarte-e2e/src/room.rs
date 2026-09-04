use std::sync::Arc;
use std::time::Duration;

use eyre::{Context, ensure};
use phoenix_chan::Message;
use phoenix_chan::tungstenite::http::Uri;
use serde::{Deserialize, Serialize};
use tokio::sync::broadcast;
use tokio::task::JoinSet;
use tracing::{error, trace};

use crate::{
    astarte_event::{
        DeviceConnectedEvent, IncomingDataEvent, RoomEvent, SimpleTrigger, SimpleTriggerTarget,
    },
    config::AstarteConfig,
};

#[derive(Debug)]
pub enum Reply {
    PhxReply(Message<PhxReply>),
    NewEvent(Message<RoomEvent>),
}

impl Reply {
    pub fn as_phx_reply(&self) -> Option<&Message<PhxReply>> {
        if let Self::PhxReply(v) = self {
            Some(v)
        } else {
            None
        }
    }

    pub fn as_new_event(&self) -> Option<&Message<RoomEvent>> {
        if let Self::NewEvent(v) = self {
            Some(v)
        } else {
            None
        }
    }

    pub fn try_into_phx_reply(self) -> Result<Message<PhxReply>, Box<Self>> {
        if let Self::PhxReply(v) = self {
            Ok(v)
        } else {
            Err(Box::new(self))
        }
    }

    pub fn try_into_new_event(self) -> Result<Message<RoomEvent>, Box<Self>> {
        if let Self::NewEvent(v) = self {
            Ok(v)
        } else {
            Err(Box::new(self))
        }
    }
}

#[derive(Debug)]
pub struct Room {
    name: String,
    client: Arc<phoenix_chan::Client>,
    joined: bool,
    rx: async_channel::Receiver<Reply>,
}

impl Room {
    pub async fn open(
        astarte_config: &AstarteConfig,
        device_id: &str,
        tasks: &mut JoinSet<eyre::Result<()>>,
        cancel: broadcast::Receiver<()>,
    ) -> eyre::Result<Self> {
        let realm = &astarte_config.realm;
        let jwt = astarte_config.jwt.as_str();
        let mut appengine_ws = astarte_config.appengine_websocket()?;

        appengine_ws
            .query_pairs_mut()
            .append_pair("vsn", "2.0.0")
            .append_pair("realm", realm)
            .append_pair("token", jwt);

        let uri = Uri::try_from(appengine_ws.to_string())?;

        let client = phoenix_chan::Client::builder(uri)?
            .tls_config(Arc::new(crate::tls::client_config()?))
            .connect()
            .await?;

        let client = Arc::new(client);

        let name = format!("rooms:{realm}:e2e_test_{device_id}");

        let rx = spawn_channel_recv(&client, tasks, cancel);

        Ok(Self {
            name,
            client,
            joined: false,
            rx,
        })
    }

    async fn wait_for(&mut self, id: usize) -> eyre::Result<()> {
        trace!("waiting for response");

        loop {
            let reply = tokio::time::timeout(Duration::from_secs(2), self.rx.recv())
                .await
                .wrap_err_with(|| format!("waiting for {id}"))?
                .wrap_err("channel closed")?;

            trace!(?reply, "received a new message");

            let phx_reply = reply
                .try_into_phx_reply()
                .ok()
                .filter(|phx_reply| phx_reply.message_reference == Some(id.to_string()));

            let Some(msg) = phx_reply else {
                trace!("skipping");

                continue;
            };

            trace!(?msg, "reply received");

            ensure!(msg.payload.is_ok(), "channel error {:?}", msg);

            break;
        }

        Ok(())
    }

    pub async fn join(&mut self) -> eyre::Result<()> {
        let id = self.client.join(&self.name).await?;

        self.wait_for(id).await?;

        self.joined = true;

        Ok(())
    }

    pub async fn watch(&mut self, trigger: TransitiveTrigger) -> eyre::Result<()> {
        let id = self.client.send(&self.name, "watch", trigger).await?;

        self.wait_for(id).await?;

        Ok(())
    }

    pub async fn next_event(&mut self) -> eyre::Result<RoomEvent> {
        loop {
            let reply = tokio::time::timeout(Duration::from_secs(2), self.rx.recv())
                .await
                .wrap_err("waiting for new_event")?
                .wrap_err("error receiving from channel")?;

            if let Ok(event) = reply.try_into_new_event() {
                return Ok(event.payload);
            };
        }
    }

    pub async fn next_data_event(&mut self) -> eyre::Result<IncomingDataEvent> {
        loop {
            let reply = tokio::time::timeout(Duration::from_secs(2), self.rx.recv())
                .await
                .wrap_err("waiting for new_event")?
                .wrap_err("error receiving from channel")?;

            let Ok(new_event) = reply.try_into_new_event() else {
                continue;
            };

            let Ok(data) = new_event.payload.event.try_into_incoming_data() else {
                continue;
            };

            return Ok(data);
        }
    }

    pub async fn next_device_connected_event(&mut self) -> eyre::Result<DeviceConnectedEvent> {
        loop {
            let reply = tokio::time::timeout(Duration::from_secs(2), self.rx.recv())
                .await
                .wrap_err("waiting for new_event")?
                .wrap_err("error receiving from channel")?;

            let Ok(new_event) = reply.try_into_new_event() else {
                continue;
            };

            let Ok(data) = new_event.payload.event.try_into_device_connected() else {
                continue;
            };

            return Ok(data);
        }
    }
}

impl Drop for Room {
    fn drop(&mut self) {
        if !self.joined {
            return;
        }

        let client = Arc::clone(&self.client);

        let room = std::mem::take(&mut self.name);

        tokio::spawn(async move {
            if let Err(err) = client.leave(&room).await {
                error!(
                    room,
                    error = format!("{:#}", eyre::Report::new(err)),
                    "failed to leave room"
                )
            }
        });
    }
}

#[derive(Debug, Serialize)]
pub struct TransitiveTrigger {
    pub name: String,
    #[serde(flatten)]
    pub target: SimpleTriggerTarget,
    pub simple_trigger: SimpleTrigger,
}

#[derive(Debug, Deserialize)]
pub struct PhxReply {
    pub status: PhxStatus,
    pub response: serde_json::Value,
}

impl PhxReply {
    pub(crate) fn is_ok(&self) -> bool {
        matches!(self.status, PhxStatus::Ok)
    }
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PhxStatus {
    Ok,
    Error,
}

fn spawn_channel_recv(
    client: &Arc<phoenix_chan::Client>,
    tasks: &mut JoinSet<eyre::Result<()>>,
    cancel: broadcast::Receiver<()>,
) -> async_channel::Receiver<Reply> {
    let client = Arc::clone(client);

    let (tx, rx) = async_channel::bounded::<Reply>(20);

    tasks.spawn(recv_phx_events(client, tx, cancel));

    rx
}

async fn recv_phx_events(
    client: Arc<phoenix_chan::Client>,
    tx: async_channel::Sender<Reply>,
    mut cancel: broadcast::Receiver<()>,
) -> eyre::Result<()> {
    loop {
        let message = tokio::select! {
            res = cancel.recv() => {
                res.wrap_err("channel receiver error")?;

                trace!("cancel received");

                return Ok(());
            }
            res = client.recv::<serde_json::Value>() => {
                trace!("received");

                res.wrap_err("channel receiver error").inspect_err(|err| error!(%err, "recv error"))?
            }
        };

        trace!(?message, "message received");

        match message.event_name.as_str() {
            "phx_reply" => {
                let message = message.deserialize_payload::<PhxReply>()?;

                tx.send(Reply::PhxReply(message)).await?;
            }
            "new_event" => {
                let message = message.deserialize_payload::<RoomEvent>()?;

                tx.send(Reply::NewEvent(message)).await?;
            }
            _ => {
                trace!("ignoring received event")
            }
        }
    }
}

#[cfg(test)]
mod test {
    use astarte_device_sdk::AstarteData;

    use crate::astarte_event::{
        DataTriggerCondition, DataTriggerMatchOperator, DeviceTriggerCondition, SimpleTrigger,
        SimpleTriggerTarget,
    };

    #[test]
    pub fn device_connected_serialization() {
        let trigger = SimpleTrigger::DeviceTrigger {
            on: DeviceTriggerCondition::DeviceConnected,
            target: SimpleTriggerTarget::Device {
                device_id: "0hwoPrYHQvqmZGQuEc6Wng".into(),
            },
        };
        insta::assert_json_snapshot!(trigger);
    }

    #[test]
    pub fn incoming_data_serialization() {
        let trigger = SimpleTrigger::DataTrigger {
            on: DataTriggerCondition::IncomingData,
            target: SimpleTriggerTarget::Device {
                device_id: "0hwoPrYHQvqmZGQuEc6Wng".into(),
            },
            interface_name: "*".into(),
            interface_major: 0,
            match_path: "/*".into(),
            value_match_operator: DataTriggerMatchOperator::AnyValue,
            known_value: AstarteData::String("".into()),
        };
        insta::assert_json_snapshot!(trigger);
    }
}
