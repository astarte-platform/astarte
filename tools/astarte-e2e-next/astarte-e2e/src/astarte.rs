// This file is part of Astarte.
//
// Copyright 2025 SECO Mind Srl
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

use std::fmt::Debug;

use astarte_device_sdk::AstarteData;
use color_eyre::owo_colors::OwoColorize;
use color_eyre::{Section, SectionExt};
use eyre::{Context, eyre};
use phoenix_chan::tungstenite::http;
use reqwest::header::{HeaderMap, HeaderValue};
use reqwest::{Client, ClientBuilder, Response, Url};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use tracing::debug;

use crate::base64_encode;

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct ApiData<T> {
    pub(crate) data: T,
}

impl<T> ApiData<T> {
    fn new(data: T) -> Self
    where
        T: Serialize,
    {
        Self { data }
    }
}

async fn check_response(url: &Url, res: Response) -> eyre::Result<Response> {
    let status = res.status();
    if status.is_client_error() || status.is_server_error() {
        let body: Value = res.json().await?;

        let err = eyre!("HTTP status error ({status}) for url {url}")
            .section(format!("The response body is:\n{body:#}").header("Response:".cyan()));

        Err(err)
    } else {
        Ok(res)
    }
}

#[derive(Clone)]
pub struct ApiClient {
    ///  Base url plus the realm and device id
    appengine_url: Url,
    pairing_url: Url,
    realm: String,
    device_id: String,
    client: Client,
}

impl ApiClient {
    pub fn build(
        appengine_url: Url,
        pairing_url: Url,
        realm: String,
        device_id: String,
        jwt: &str,
    ) -> eyre::Result<Self> {
        let auth = format!("Bearer {jwt}");
        let mut value = HeaderValue::from_str(&auth)?;
        value.set_sensitive(true);
        let headers = HeaderMap::from_iter([(http::header::AUTHORIZATION, value)]);

        let client = ClientBuilder::new()
            .default_headers(headers)
            .use_preconfigured_tls(crate::tls::client_config())
            .build()?;

        Ok(Self {
            appengine_url,
            pairing_url,
            realm,
            device_id,
            client,
        })
    }

    fn appengine_device_url(&self, rest: &str) -> eyre::Result<Url> {
        let url = self.appengine_url.join(&format!(
            "/appengine/v1/{}/devices/{}{}",
            self.realm, self.device_id, rest
        ))?;

        Ok(url)
    }

    pub(crate) async fn cluster_healthy(
        client: &Client,
        appengine_url: &Url,
        pairing_url: &Url,
    ) -> eyre::Result<()> {
        let res = client
            .get(appengine_url.clone())
            .send()
            .await
            .wrap_err("appengine call failed")?;
        check_response(&appengine_url, res)
            .await
            .wrap_err("appengine call failed")?;

        let res = client
            .get(pairing_url.clone())
            .send()
            .await
            .wrap_err("pairing call failed")?;
        check_response(&pairing_url, res)
            .await
            .wrap_err("pairing call failed")?;

        Ok(())
    }

    pub(crate) async fn is_healthy(&self) -> eyre::Result<()> {
        Self::cluster_healthy(&self.client, &self.appengine_url, &self.pairing_url).await
    }

    pub(crate) async fn interfaces(&self) -> eyre::Result<Vec<String>> {
        let url = self.appengine_device_url("/interfaces")?;

        let res = self.client.get(url.clone()).send().await?;
        let res = check_response(&url, res).await?;

        let payload: ApiData<Vec<String>> = res.json().await?;

        Ok(payload.data)
    }

    pub(crate) async fn send_on_interface<T>(
        &self,
        interface: &str,
        path: &str,
        data: T,
    ) -> eyre::Result<()>
    where
        T: Serialize + Debug,
    {
        let url = self.appengine_device_url(&format!(
            "/interfaces/{interface}/{}",
            path.trim_start_matches('/')
        ))?;

        let api_data = ApiData::new(data);

        debug!(?api_data);

        let res = self.client.post(url.clone()).json(&api_data).send().await?;

        check_response(&url, res).await?;

        Ok(())
    }

    pub(crate) async fn send_individual(
        &self,
        interface: &str,
        path: &str,
        data: &AstarteData,
    ) -> eyre::Result<()> {
        let value = convert_type_to_json(data);

        debug!("value {value}");

        self.send_on_interface(interface, path, value).await
    }

    pub(crate) async fn unset(&self, interface: &str, path: &str) -> eyre::Result<()> {
        let url = self.appengine_device_url(&format!(
            "/interfaces/{interface}/{}",
            path.trim_start_matches('/')
        ))?;

        let res = self.client.delete(url.clone()).send().await?;

        check_response(&url, res).await?;

        Ok(())
    }
}

pub(crate) fn convert_type_to_json(data: &AstarteData) -> serde_json::Value {
    match data {
        AstarteData::Double(v) => Value::from(f64::from(*v)),
        AstarteData::Integer(v) => Value::from(*v),
        AstarteData::Boolean(v) => Value::from(*v),
        AstarteData::LongInteger(v) => Value::from(*v),
        AstarteData::String(v) => Value::from(v.as_str()),
        AstarteData::BinaryBlob(v) => Value::from(base64_encode(v)),
        AstarteData::DateTime(v) => Value::from(v.to_rfc3339()),
        AstarteData::DoubleArray(v) => {
            Value::from(v.iter().map(|v| f64::from(*v)).collect::<Vec<f64>>())
        }
        AstarteData::IntegerArray(v) => Value::from(v.as_slice()),
        AstarteData::BooleanArray(v) => Value::from(v.as_slice()),
        AstarteData::LongIntegerArray(v) => Value::from(v.as_slice()),
        AstarteData::StringArray(v) => Value::from(v.as_slice()),
        AstarteData::BinaryBlobArray(v) => {
            Value::from(v.iter().map(base64_encode).collect::<Vec<String>>())
        }
        AstarteData::DateTimeArray(v) => {
            Value::from(v.iter().map(|d| d.to_rfc3339()).collect::<Vec<String>>())
        }
    }
}
