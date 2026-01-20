// This file is part of Astarte.
//
// Copyright 2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

use std::sync::Arc;
use std::time::Duration;

use eyre::{Context, ensure};
use phoenix_chan::Message;
use phoenix_chan::tungstenite::http::Uri;
use reqwest::Url;
use serde::{Deserialize, Serialize};
use tokio::sync::broadcast;
use tokio::task::JoinSet;
use tracing::{error, instrument, trace};

use crate::astarte_event::{IncomingData, SimpleEvent};

#[derive(Debug)]
pub enum Reply {
    PhxReply(Box<Message<PhxReply>>),
    NewEvent(Box<Message<SimpleEvent>>),
}

impl Reply {
    pub fn as_phx_reply(&self) -> Option<&Message<PhxReply>> {
        if let Self::PhxReply(v) = self {
            Some(v)
        } else {
            None
        }
    }

    pub fn as_new_event(&self) -> Option<&Message<SimpleEvent>> {
        if let Self::NewEvent(v) = self {
            Some(v)
        } else {
            None
        }
    }

    pub fn try_into_phx_reply(self) -> Result<Message<PhxReply>, Self> {
        if let Self::PhxReply(v) = self {
            Ok(*v)
        } else {
            Err(self)
        }
    }

    pub fn try_into_new_event(self) -> Result<Message<SimpleEvent>, Self> {
        if let Self::NewEvent(v) = self {
            Ok(*v)
        } else {
            Err(self)
        }
    }
}

#[derive(Debug)]
pub struct PhoenixChannel {
    room: String,
    device_id: String,
    client: Arc<phoenix_chan::Client>,
    joined: bool,
    rx: async_channel::Receiver<Reply>,
}

impl PhoenixChannel {
    pub async fn connect(
        mut appengine_ws: Url,
        realm: &str,
        token: &str,
        device_id: &str,
        tasks: &mut JoinSet<eyre::Result<()>>,
        cancel: broadcast::Receiver<()>,
    ) -> eyre::Result<Self> {
        appengine_ws
            .query_pairs_mut()
            .append_pair("vsn", "2.0.0")
            .append_pair("realm", realm)
            .append_pair("token", token);

        let uri = Uri::try_from(appengine_ws.to_string())?;

        let client = phoenix_chan::Client::builder(dbg!(uri))?
            .tls_config(Arc::new(crate::tls::client_config()?))
            .connect()
            .await?;
        let client = Arc::new(client);

        let room = format!("rooms:{realm}:e2e_test_{device_id}");

        let rx = spawn_channel_recv(&client, tasks, cancel);

        Ok(Self {
            room,
            device_id: device_id.to_string(),
            client,
            joined: false,
            rx,
        })
    }

    #[instrument(skip(self))]
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

    #[instrument(skip(self))]
    pub async fn join(&mut self) -> eyre::Result<()> {
        let id = self.client.join(&self.room).await?;

        self.wait_for(id).await?;

        self.joined = true;

        Ok(())
    }

    #[instrument(skip(self, trigger), fields(trigger_name = trigger.name))]
    pub(crate) async fn watch(&mut self, trigger: TransitiveTrigger<'_>) -> eyre::Result<()> {
        let id = self.client.send(&self.room, "watch", trigger).await?;

        self.wait_for(id).await?;

        Ok(())
    }

    #[instrument(skip(self))]
    pub(crate) async fn next_data_event(&mut self) -> eyre::Result<IncomingData> {
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
}

impl Drop for PhoenixChannel {
    fn drop(&mut self) {
        if !self.joined {
            return;
        }

        let client = Arc::clone(&self.client);

        let room = std::mem::take(&mut self.room);

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
pub(crate) struct TransitiveTrigger<'a> {
    pub(crate) name: &'a str,
    pub(crate) device_id: &'a str,
    pub(crate) simple_trigger: SimpleTrigger<'a>,
}

#[derive(Debug, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub(crate) enum SimpleTrigger<'a> {
    DeviceTrigger {
        on: DeviceTriggerCondition,
        device_id: &'a str,
    },
    DataTrigger {
        on: DataTriggerCondition,
        device_id: &'a str,
        interface_name: &'a str,
        match_path: &'a str,
        value_match_operator: &'a str,
    },
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum DeviceTriggerCondition {
    DeviceConnected,
    DeviceDisconnected,
    DeviceError,
    DeviceEmptyCacheReceived,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum DataTriggerCondition {
    IncomingData,
    ValueStored,
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

#[instrument(skip_all)]
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

                tx.send(Reply::PhxReply(Box::new(message))).await?;
            }
            "new_event" => {
                let message = message.deserialize_payload::<SimpleEvent>()?;

                tx.send(Reply::NewEvent(Box::new(message))).await?;
            }
            _ => {
                trace!("ignoring received event")
            }
        }
    }
}

pub(crate) async fn register_triggers(channel: &mut PhoenixChannel) -> eyre::Result<()> {
    channel.join().await?;
    let device_id = &channel.device_id.clone();

    channel
        .watch(TransitiveTrigger {
            name: &format!("connectiontrigger-{device_id}"),
            device_id,
            simple_trigger: SimpleTrigger::DeviceTrigger {
                on: DeviceTriggerCondition::DeviceConnected,
                device_id,
            },
        })
        .await?;

    channel
        .watch(TransitiveTrigger {
            name: &format!("disconnectiontrigger-{device_id}"),
            device_id,
            simple_trigger: SimpleTrigger::DeviceTrigger {
                on: DeviceTriggerCondition::DeviceDisconnected,
                device_id,
            },
        })
        .await?;

    channel
        .watch(TransitiveTrigger {
            name: &format!("errortrigger-{device_id}"),
            device_id,
            simple_trigger: SimpleTrigger::DeviceTrigger {
                on: DeviceTriggerCondition::DeviceError,
                device_id,
            },
        })
        .await?;

    channel
        .watch(TransitiveTrigger {
            name: &format!("datatrigger-{device_id}"),
            device_id,
            simple_trigger: SimpleTrigger::DataTrigger {
                on: DataTriggerCondition::IncomingData,
                device_id,
                interface_name: "*",
                match_path: "/*",
                value_match_operator: "*",
            },
        })
        .await?;

    Ok(())
}
