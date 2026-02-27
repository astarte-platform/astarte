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

pub mod astarte;
mod astarte_event;
pub mod interfaces;
mod tls;
pub mod transport;

use astarte_device_sdk::{
    AstarteData, DeviceConnection, EventLoop,
    builder::DeviceBuilder,
    store::SqliteStore,
    transport::mqtt::{Credential, Mqtt, MqttConfig},
};
use base64::Engine;
use base64::prelude::BASE64_STANDARD;
use chrono::{DateTime, Utc};
use eyre::{Context, eyre};
use serde_json::Value;
use std::{path::Path, str::FromStr};
use tokio::task::JoinSet;

use crate::interfaces::AstarteClient;

const INTERFACE_DIR: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/interfaces");

pub fn add(left: u64, right: u64) -> u64 {
    left + right
}

pub(crate) type Timestamp = DateTime<Utc>;

pub(crate) fn base64_decode<T>(input: T) -> Result<Vec<u8>, base64::DecodeError>
where
    T: AsRef<[u8]>,
{
    BASE64_STANDARD.decode(input)
}

pub(crate) fn base64_encode<T>(input: T) -> String
where
    T: AsRef<[u8]>,
{
    BASE64_STANDARD.encode(input)
}

pub(crate) fn timestamp_from_rfc3339(input: &str) -> chrono::ParseResult<Timestamp> {
    DateTime::parse_from_rfc3339(input).map(|d| d.to_utc())
}

pub(crate) fn check_astarte_value(data: &AstarteData, value: &Value) -> eyre::Result<()> {
    let eq = match data {
        AstarteData::Double(exp) => value.as_f64().is_some_and(|v| v == *exp),
        AstarteData::Integer(exp) => value.as_i64().is_some_and(|v| v == i64::from(*exp)),
        AstarteData::Boolean(exp) => value.as_bool().is_some_and(|v| v == *exp),
        AstarteData::LongInteger(exp) => value.as_i64().is_some_and(|v| v == *exp),
        AstarteData::String(exp) => value.as_str().is_some_and(|v| v == exp),
        AstarteData::BinaryBlob(exp) => value
            .as_str()
            .map(base64_decode)
            .transpose()?
            .is_some_and(|blob| blob == *exp),
        AstarteData::DateTime(exp) => value
            .as_str()
            .map(Timestamp::from_str)
            .transpose()?
            .is_some_and(|date_time| date_time == *exp),
        AstarteData::DoubleArray(exp) => {
            let arr: Vec<f64> = serde_json::from_value(value.clone())?;

            arr == *exp
        }
        AstarteData::IntegerArray(exp) => {
            let arr: Vec<i32> = serde_json::from_value(value.clone())?;

            arr == *exp
        }
        AstarteData::BooleanArray(exp) => {
            let arr: Vec<bool> = serde_json::from_value(value.clone())?;

            arr == *exp
        }
        AstarteData::LongIntegerArray(exp) => {
            let arr: Vec<i64> = serde_json::from_value(value.clone())?;

            arr == *exp
        }
        AstarteData::StringArray(exp) => {
            let arr: Vec<String> = serde_json::from_value(value.clone())?;

            arr == *exp
        }
        AstarteData::BinaryBlobArray(exp) => {
            let arr: Vec<String> = serde_json::from_value(value.clone())?;
            let arr = arr
                .into_iter()
                .map(base64_decode)
                .collect::<Result<Vec<_>, _>>()?;

            arr == *exp
        }
        AstarteData::DateTimeArray(exp) => {
            let arr: Vec<String> = serde_json::from_value(value.clone())?;
            let arr = arr
                .into_iter()
                .map(|v| Timestamp::from_str(&v))
                .collect::<Result<Vec<_>, _>>()?;

            arr == *exp
        }
    };

    if !eq {
        Err(eyre!("data {data:?} != {value}"))
    } else {
        Ok(())
    }
}

pub async fn device_client<P>(
    realm: &str,
    device_id: &str,
    credentials_secret: &str,
    pairing_url: &str,
    store: &P,
    ignore_ssl_errors: bool,
) -> eyre::Result<(AstarteClient, DeviceConnection<Mqtt<SqliteStore>>)>
where
    P: AsRef<Path>,
{
    let mut mqtt_config = MqttConfig::new(
        realm,
        device_id,
        Credential::secret(credentials_secret),
        pairing_url,
    );

    if ignore_ssl_errors {
        mqtt_config.ignore_ssl_errors();
    }

    DeviceBuilder::new()
        .store_dir(store)
        .await?
        .interface_directory(INTERFACE_DIR)?
        .connection(mqtt_config)
        .build()
        .await
        .wrap_err("device builder failed")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        let result = add(2, 2);
        assert_eq!(result, 4);
    }
}
