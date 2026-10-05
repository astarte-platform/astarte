#[rustfmt::skip]
pub mod simple_events;

pub mod amqp_trigger_consumer;
pub mod astarte;
pub mod astarte_event;
pub mod config;
pub mod device_room;
pub mod interfaces;
pub mod room;
pub mod scenarios;
mod tls;

use astarte_device_sdk::{
    AstarteData, DeviceConnection,
    builder::DeviceBuilder,
    pairing::api::PairingApi,
    store::SqliteStore,
    transport::mqtt::{Credential, Mqtt, MqttArgs, MqttConfig},
};
use base64::Engine;
use base64::prelude::BASE64_STANDARD;
use chrono::{DateTime, Utc};
use eyre::{Context, eyre};
use reqwest::Url;
use serde_json::Value;
use std::{path::Path, str::FromStr};

use crate::interfaces::AstarteClient;

const INTERFACE_DIR: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/interfaces");

pub(crate) type Timestamp = DateTime<Utc>;

pub(crate) fn base64_decode<T>(input: T) -> Result<Vec<u8>, base64::DecodeError>
where
    T: AsRef<[u8]>,
{
    BASE64_STANDARD.decode(input)
}

pub fn base64_encode<T>(input: T) -> String
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
    credential: Credential,
    pairing_url: Url,
    store_dir: &P,
    ignore_ssl_errors: bool,
) -> eyre::Result<(
    AstarteClient,
    DeviceConnection<Mqtt<SqliteStore, PairingApi>>,
)>
where
    P: AsRef<Path>,
{
    let mut mqtt_config = MqttConfig::new(MqttArgs {
        realm: realm.to_string(),
        device_id: device_id.to_string(),
        credential,
        pairing_url,
    });

    if ignore_ssl_errors {
        mqtt_config = mqtt_config.ignore_ssl_errors();
    }

    let store = SqliteStore::options().with_writable_dir(&store_dir).await?;

    DeviceBuilder::new()
        .writable_dir(store_dir)
        .store(store)
        .interface_directory(INTERFACE_DIR)?
        .connection(mqtt_config)
        .build()
        .await
        .wrap_err("device builder failed")
}
