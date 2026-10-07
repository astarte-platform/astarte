mod config;
pub mod interfaces;

use crate::config::Config;
use clap::Parser;

#[tokio::main]
async fn main() -> eyre::Result<()> {
    let config = Config::try_parse()?;
    config.run().await
}
