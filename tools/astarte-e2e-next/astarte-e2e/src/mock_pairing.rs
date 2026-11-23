use mockito::{Mock, Server, ServerGuard};
use reqwest::Url;
use serde_json::{Value, json};

/// Pairing API that accepts any certificate, letting the device connect to the
/// broker with a certificate the real pairing would make it replace.
///
/// It only answers the calls of an already registered device with a stored
/// certificate: the certificate verification and the device info (broker URL).
pub struct MockPairing {
    server: ServerGuard,
    _mocks: [Mock; 2],
}

impl MockPairing {
    /// Start the mock, answering the device info with the given body.
    pub async fn start(realm: &str, device_id: &str, info: &Value) -> Self {
        let mut server = Server::new_async().await;

        let device_path = format!("/v1/{realm}/devices/{device_id}");

        let info = server
            .mock("GET", device_path.as_str())
            .with_status(200)
            .with_header("content-type", "application/json")
            .with_body(info.to_string())
            .create_async()
            .await;

        let verify = server
            .mock(
                "POST",
                format!("{device_path}/protocols/astarte_mqtt_v1/credentials/verify").as_str(),
            )
            .with_status(200)
            .with_header("content-type", "application/json")
            .with_body(json!({ "data": { "valid": true } }).to_string())
            .create_async()
            .await;

        Self {
            server,
            _mocks: [info, verify],
        }
    }

    pub fn url(&self) -> eyre::Result<Url> {
        Ok(Url::parse(&self.server.url())?)
    }
}
