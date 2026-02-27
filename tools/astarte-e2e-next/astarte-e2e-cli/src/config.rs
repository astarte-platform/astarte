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

use clap::{Args, Parser, Subcommand};
use color_eyre::Section;
use eyre::eyre;
use reqwest::Url;

use astarte_e2e::astarte::ApiClient;

#[derive(Debug, Args)]
pub(crate) struct AstarteConfig {
    /// Astarte Pairing URL
    #[arg(
        long,
        env = "E2E_PAIRING_URL",
        default_value = "http://api.astarte.localhost/pairing/"
    )]
    /// Astarte AppEngine URL
    pub(crate) astarte_pairing_url: Url,
    #[arg(
        long,
        env = "E2E_APPENGINE_URL",
        default_value = "http://api.astarte.localhost/appengine/"
    )]
    pub(crate) astarte_appengine_url: Url,
    /// Ignore SSL validation
    #[arg(long, env = "E2E_IGNORE_SSL_ERRORS", default_value = "false")]
    pub(crate) ignore_ssl: bool,
    /// Realm of the device.
    #[arg(long, short, env = "E2E_REALM", default_value = "test")]
    pub(crate) realm: String,
    /// Device id.
    #[arg(long, short, env = "E2E_DEVICE_ID")]
    pub(crate) device_id: String,
    /// Device credentials secret.
    #[arg(long, short, env = "E2E_CREDENTIALS_SECRET")]
    pub(crate) credentials_secret: String,
    /// JWT Token with access to all realm APIs.
    #[arg(long, short, env = "E2E_JWT")]
    pub(crate) jwt: String,
}

impl AstarteConfig {
    pub(crate) fn appengine_websocket(&self) -> eyre::Result<Url> {
        let mut websocket_url = self.astarte_appengine_url.clone();
        let scheme = match websocket_url.scheme() {
            "http" => Ok("ws"),
            "https" => Ok("wss"),
            other => Err(eyre!("invalid appengine scheme #{other}")),
        }?;

        websocket_url.set_scheme(scheme).map_err(|()| {
            eyre!("couldn't set the scheme {scheme}").note(format!("for url {websocket_url}"))
        })?;

        let websocket_url = websocket_url.join("v1/socket/websocket")?;

        Ok(websocket_url)
    }
}

#[derive(Debug, Parser)]
pub(crate) struct Config {
    #[command(flatten)]
    pub(crate) astarte: AstarteConfig,
    #[command(subcommand)]
    pub(crate) monitor: Monitor,
}

#[derive(Debug, Subcommand)]
pub(crate) enum Monitor {
    IndividualDatastream(crate::interfaces::device::individual_datastream::Config),
}

impl Config {
    pub(crate) fn api_client(&self) -> eyre::Result<ApiClient> {
        ApiClient::build(
            self.astarte.astarte_appengine_url.clone(),
            self.astarte.astarte_pairing_url.clone(),
            self.astarte.realm.clone(),
            self.astarte.device_id.clone(),
            &self.astarte.jwt,
        )
    }
}

#[cfg(test)]
pub(crate) mod utils {
    use clap::Parser;

    use super::AstarteConfig;

    #[derive(Debug, Parser)]
    pub struct Astarte {
        #[command(flatten)]
        pub astarte: AstarteConfig,
    }
}
