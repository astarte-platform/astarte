use astarte_e2e::{config::Config, scenarios::certificate_revocation::Variant};

// TODO: expect success once the broker refuses superseded certificates
#[tokio::test]
#[should_panic(expected = "the device connected with the superseded certificate")]
async fn superseded_broker() {
    Variant::SupersededBroker
        .run(Config::from_env().unwrap())
        .await
        .unwrap();
}

// TODO: expect success once pairing checks whether a certificate was revoked
#[tokio::test]
#[should_panic(expected = "pairing reported the superseded certificate as valid")]
async fn superseded_pairing() {
    Variant::SupersededPairing
        .run(Config::from_env().unwrap())
        .await
        .unwrap();
}
