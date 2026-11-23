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

use crate::astarte_event::Trigger;
use crate::base64_encode;

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ApiData<T> {
    pub data: T,
}

impl<T> ApiData<T> {
    pub fn new(data: T) -> Self
    where
        T: Serialize,
    {
        Self { data }
    }
}

pub async fn check_response(url: &Url, res: Response) -> eyre::Result<Response> {
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
    pub appengine_url: Url,
    pub pairing_url: Url,
    pub realm_management_url: Url,
    pub realm: String,
    pub device_id: String,
    pub client: Client,
}

impl ApiClient {
    pub fn build(
        appengine_url: Url,
        pairing_url: Url,
        realm_management_url: Url,
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
            .use_preconfigured_tls(crate::tls::client_config()?)
            .build()?;

        Ok(Self {
            appengine_url,
            pairing_url,
            realm_management_url,
            realm,
            device_id,
            client,
        })
    }

    pub fn appengine_device_url(&self, rest: &str) -> eyre::Result<Url> {
        let url = self.appengine_url.join(&format!(
            "/v1/{}/devices/{}{}",
            self.realm, self.device_id, rest
        ))?;

        Ok(url)
    }

    pub async fn cluster_healthy(
        client: &Client,
        appengine_url: &Url,
        pairing_url: &Url,
        realm_management_url: &Url,
    ) -> eyre::Result<()> {
        let res = client
            .get(appengine_url.clone())
            .send()
            .await
            .wrap_err("appengine call failed")?;

        check_response(appengine_url, res)
            .await
            .wrap_err("appengine call failed")?;

        let res = client
            .get(pairing_url.clone())
            .send()
            .await
            .wrap_err("pairing call failed")?;

        check_response(pairing_url, res)
            .await
            .wrap_err("pairing call failed")?;

        let res = client
            .get(realm_management_url.clone())
            .send()
            .await
            .wrap_err("realm_management call failed")?;

        check_response(realm_management_url, res)
            .await
            .wrap_err("realm_management call failed")?;

        Ok(())
    }

    pub async fn is_healthy(&self) -> eyre::Result<()> {
        Self::cluster_healthy(
            &self.client,
            &self.appengine_url,
            &self.pairing_url,
            &self.realm_management_url,
        )
        .await
    }

    pub async fn interfaces(&self) -> eyre::Result<Vec<String>> {
        let url = self.appengine_device_url("/interfaces")?;

        let res = self.client.get(url.clone()).send().await?;
        let res = check_response(&url, res).await?;

        let payload: ApiData<Vec<String>> = res.json().await?;

        Ok(payload.data)
    }

    pub async fn send_on_interface<T>(
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

    pub async fn send_individual(
        &self,
        interface: &str,
        path: &str,
        data: &AstarteData,
    ) -> eyre::Result<()> {
        let value = convert_type_to_json(data);

        debug!("value {value}");

        self.send_on_interface(interface, path, value).await
    }

    pub async fn unset(&self, interface: &str, path: &str) -> eyre::Result<()> {
        let url = self.appengine_device_url(&format!(
            "/interfaces/{interface}/{}",
            path.trim_start_matches('/')
        ))?;

        let res = self.client.delete(url.clone()).send().await?;

        check_response(&url, res).await?;

        Ok(())
    }

    pub async fn install_trigger(&self, trigger: &Trigger) -> eyre::Result<()> {
        let path = format!("v1/{}/triggers", self.realm);
        let url = self.realm_management_url.join(&path)?;

        let body = serde_json::json!({ "data": trigger });
        let res = self.client.post(url.clone()).json(&body).send().await?;

        check_response(&url, res).await?;

        Ok(())
    }

    fn pairing_device_url(&self, rest: &str) -> eyre::Result<Url> {
        let path = format!("v1/{}/devices/{}{}", self.realm, self.device_id, rest);
        let url = self.pairing_url.join(&path)?;

        Ok(url)
    }

    /// Raw response body of the device info from pairing, containing the
    /// broker URL.
    ///
    /// Authenticated as the device with its credentials secret.
    pub async fn pairing_device_info(&self, credentials_secret: &str) -> eyre::Result<Value> {
        let url = self.pairing_device_url("")?;

        let res = self
            .client
            .get(url.clone())
            .bearer_auth(credentials_secret)
            .send()
            .await?;
        let res = check_response(&url, res).await?;

        Ok(res.json().await?)
    }

    /// Authenticated as the device with its credentials secret.
    pub async fn verify_certificate(
        &self,
        credentials_secret: &str,
        client_crt: &str,
    ) -> eyre::Result<CertificateStatus> {
        let url = self.pairing_device_url("/protocols/astarte_mqtt_v1/credentials/verify")?;

        let body = serde_json::json!({ "data": { "client_crt": client_crt } });
        let res = self
            .client
            .post(url.clone())
            .bearer_auth(credentials_secret)
            .json(&body)
            .send()
            .await?;
        let res = check_response(&url, res).await?;

        let payload: ApiData<CertificateStatus> = res.json().await?;

        Ok(payload.data)
    }
}

#[derive(Debug, Deserialize)]
pub struct CertificateStatus {
    pub valid: bool,
    #[serde(default)]
    pub cause: Option<String>,
}

pub fn convert_type_to_json(data: &AstarteData) -> serde_json::Value {
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
