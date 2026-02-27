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

mod config;
pub mod interfaces;

use astarte_e2e::add;

use crate::config::Config;
use clap::Parser;

fn main() {
    let _config = Config::parse();
    let result = add(3, 4);
    dbg!(result);
    println!("Hello, world!");
}

#[cfg(test)]
pub mod utils {
    use astarte_device_sdk::EventLoop;
    use astarte_e2e::device_client;
    use astarte_e2e::{interfaces::AstarteClient, transport::phoenix_channel::PhoenixChannel};
    use clap::Parser;
    use eyre::Context;
    use tempfile::TempDir;
    use tokio::sync::broadcast::Sender;
    use tokio::task::JoinSet;

    use crate::config::utils::Astarte;

    pub(crate) struct State {
        store: TempDir,
        pub channel: PhoenixChannel,
        pub client: AstarteClient,
        tx_cancel: Sender<()>,
    }

    impl Drop for State {
        fn drop(&mut self) {
            let _ = self.tx_cancel.send(());
        }
    }

    pub(crate) async fn connect_to_astarte() -> eyre::Result<State> {
        let astarte_config = Astarte::parse();
        let appengine_ws = astarte_config.astarte.appengine_websocket()?;
        let store = TempDir::new()?;

        let (tx_cancel, mut cancel) = tokio::sync::broadcast::channel::<()>(2);
        let mut tasks = JoinSet::<eyre::Result<()>>::new();

        let mut channel = PhoenixChannel::connect(
            appengine_ws,
            &astarte_config.astarte.realm,
            dbg!(&astarte_config.astarte.jwt),
            &astarte_config.astarte.device_id,
            &mut tasks,
            tx_cancel.subscribe(),
        )
        .await?;

        channel.join().await?;

        let (client, connection) = device_client(
            &astarte_config.astarte.realm,
            &astarte_config.astarte.device_id,
            &astarte_config.astarte.credentials_secret,
            &astarte_config.astarte.astarte_pairing_url.to_string(),
            &store,
            astarte_config.astarte.ignore_ssl,
        )
        .await?;

        tasks.spawn(async move {
            tokio::select! {
                res = cancel.recv() => {
                    res.wrap_err("couldn't cancel handle events")?;
                }
                res = connection.handle_events() => {
                    res.wrap_err("handle events errored")?;
                }
            }

            Ok(())
        });

        let state = State {
            store,
            channel,
            client,
            tx_cancel,
        };

        Ok(state)
    }
}
