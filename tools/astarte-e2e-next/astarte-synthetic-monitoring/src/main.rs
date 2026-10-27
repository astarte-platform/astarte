mod config;
pub mod interfaces;

use crate::config::SyntheticMonitoringConfig;

#[tokio::main]
async fn main() -> eyre::Result<()> {
    let config = SyntheticMonitoringConfig::parse_with_default()?;
    config.run().await
}
