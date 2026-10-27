use rustls::ClientConfig;
use rustls_platform_verifier::ConfigVerifierExt;

/// Read an returns the certificates roots
pub(crate) fn client_config() -> eyre::Result<ClientConfig> {
    ClientConfig::with_platform_verifier().map_err(Into::into)
}
