#[cfg(feature = "clap")]
use clap::{Args, Parser};
use color_eyre::Section;
use eyre::eyre;
use reqwest::Url;

use crate::astarte::ApiClient;

#[derive(Debug)]
#[cfg_attr(feature = "clap", derive(Args))]
pub struct AstarteConfig {
    /// Astarte API URL
    #[cfg_attr(
        feature = "clap",
        arg(
            long,
            env = "E2E_ASTARTE_API_URL",
            default_value = "http://api.astarte.localhost/"
        )
    )]
    pub astarte_api_url: Url,
    /// Astarte Pairing URL (defaults to `{astarte_api_url}pairing/`)
    #[cfg_attr(feature = "clap", arg(long, env = "E2E_PAIRING_URL"))]
    pub astarte_pairing_url: Option<Url>,
    /// Astarte AppEngine URL (defaults to `{astarte_api_url}appengine/`)
    #[cfg_attr(feature = "clap", arg(long, env = "E2E_APPENGINE_URL"))]
    pub astarte_appengine_url: Option<Url>,
    /// Astarte Realm Management URL (defaults to `{astarte_api_url}realmmanagement/`)
    #[cfg_attr(feature = "clap", arg(long, env = "E2E_REALM_MANAGEMENT_URL"))]
    pub astarte_realm_management_url: Option<Url>,
    /// Ignore SSL validation
    #[cfg_attr(
        feature = "clap",
        arg(long, env = "E2E_IGNORE_SSL_ERRORS", default_value = "false")
    )]
    pub ignore_ssl: bool,
    /// Realm of the device.
    #[cfg_attr(
        feature = "clap",
        arg(long, short, env = "E2E_REALM", default_value = "test")
    )]
    pub realm: String,
    /// JWT Token with access to all realm APIs.
    #[cfg_attr(feature = "clap", arg(long, short, env = "E2E_JWT"))]
    pub jwt: String,
}

#[derive(Debug)]
#[cfg_attr(feature = "clap", derive(Args))]
pub struct DeviceConfig {
    /// Device id.
    #[cfg_attr(feature = "clap", arg(long, short, env = "E2E_DEVICE_ID"))]
    pub device_id: Option<String>,
    /// Device credentials secret.
    #[cfg_attr(feature = "clap", arg(long, short, env = "E2E_CREDENTIALS_SECRET"))]
    pub credentials_secret: Option<String>,
}

impl AstarteConfig {
    fn derived_url(api_url: &Url, path: &str) -> eyre::Result<Url> {
        let mut api_url = api_url.clone();
        if !api_url.path().ends_with('/') {
            let dir_path = format!("{}/", api_url.path());
            api_url.set_path(&dir_path);
        }

        Ok(api_url.join(path)?)
    }

    pub fn pairing_url(&self) -> eyre::Result<Url> {
        self.astarte_pairing_url
            .clone()
            .map(Ok)
            .unwrap_or_else(|| Self::derived_url(&self.astarte_api_url, "pairing/"))
    }

    pub fn appengine_url(&self) -> eyre::Result<Url> {
        self.astarte_appengine_url
            .clone()
            .map(Ok)
            .unwrap_or_else(|| Self::derived_url(&self.astarte_api_url, "appengine/"))
    }

    pub fn realm_management_url(&self) -> eyre::Result<Url> {
        self.astarte_realm_management_url
            .clone()
            .map(Ok)
            .unwrap_or_else(|| Self::derived_url(&self.astarte_api_url, "realmmanagement/"))
    }

    pub fn appengine_websocket(&self) -> eyre::Result<Url> {
        let mut websocket_url = self.appengine_url()?;
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

#[derive(Debug)]
#[cfg_attr(feature = "clap", derive(Args))]
pub struct AmqpConfig {
    /// RabbitMQ host for trigger events
    #[cfg_attr(
        feature = "clap",
        arg(long, env = "E2E_AMQP_CONSUMER_HOST", default_value = "localhost")
    )]
    pub amqp_consumer_host: String,
    /// RabbitMQ port for trigger events
    #[cfg_attr(
        feature = "clap",
        arg(long, env = "E2E_AMQP_CONSUMER_PORT", default_value = "5672")
    )]
    pub amqp_consumer_port: u16,
    /// RabbitMQ username for trigger events
    #[cfg_attr(
        feature = "clap",
        arg(long, env = "E2E_AMQP_CONSUMER_USERNAME", default_value = "guest")
    )]
    pub amqp_consumer_username: String,
    /// RabbitMQ password for trigger events
    #[cfg_attr(
        feature = "clap",
        arg(long, env = "E2E_AMQP_CONSUMER_PASSWORD", default_value = "guest")
    )]
    pub amqp_consumer_password: String,
}

impl AmqpConfig {
    pub fn uri(&self) -> String {
        format!(
            "amqp://{}:{}@{}:{}",
            self.amqp_consumer_username,
            self.amqp_consumer_password,
            self.amqp_consumer_host,
            self.amqp_consumer_port,
        )
    }
}

#[derive(Debug)]
#[cfg_attr(feature = "clap", derive(Parser))]
pub struct Config {
    #[cfg_attr(feature = "clap", command(flatten))]
    pub astarte: AstarteConfig,
    #[cfg_attr(feature = "clap", command(flatten))]
    pub device: DeviceConfig,
    #[cfg_attr(feature = "clap", command(flatten))]
    pub amqp: AmqpConfig,
}

impl Config {
    pub fn api_client(&self) -> eyre::Result<ApiClient> {
        let device_id = self
            .device
            .device_id
            .clone()
            .ok_or_else(|| eyre!("missing device id, required to build the API client"))?;

        ApiClient::build(
            self.astarte.appengine_url()?,
            self.astarte.pairing_url()?,
            self.astarte.realm_management_url()?,
            self.astarte.realm.clone(),
            device_id,
            &self.astarte.jwt,
        )
    }
}

#[cfg(test)]
mod test {
    use reqwest::Url;

    use super::AstarteConfig;

    #[test]
    pub fn pairing_url_from_config() -> eyre::Result<()> {
        let pairing_url = Url::parse("https://example.org/custom-pairing-url/")?;
        let config = new_astarte_config("http://api.astarte.localhost/")?;
        let config = AstarteConfig {
            astarte_pairing_url: Some(pairing_url.clone()),
            ..config
        };

        assert_eq!(config.pairing_url()?, pairing_url);

        Ok(())
    }

    #[test]
    pub fn pairing_url_from_astarte_url() -> eyre::Result<()> {
        let config = new_astarte_config("http://api.astarte.localhost/")?;
        let pairing_url = Url::parse("http://api.astarte.localhost/pairing/")?;

        assert_eq!(config.pairing_url()?, pairing_url);

        Ok(())
    }

    fn new_astarte_config(astarte_api_url: &str) -> eyre::Result<AstarteConfig> {
        Ok(AstarteConfig {
            astarte_api_url: Url::parse(astarte_api_url)?,
            astarte_pairing_url: None,
            astarte_appengine_url: None,
            astarte_realm_management_url: None,
            ignore_ssl: false,
            realm: "".into(),
            jwt: "".into(),
        })
    }
}
