//! Regenerator for the prost types generated from the Astarte `simple_events`
//! protos, used through the `regen-proto` cargo alias:
//!
//! ```sh
//! cargo regen-proto           # write src/simple_events.rs
//! cargo regen-proto --check   # fail if src/simple_events.rs is out of date
//! ```

use std::fs;
use std::path::PathBuf;

use eyre::{Context, bail, eyre};
use prost_build::Config;

const SERDE_DERIVE: &str = "#[derive(::serde::Serialize)] #[derive(::serde::Deserialize)]";

const OUT_FILE: &str = "src/simple_events.rs";

fn prost_config() -> Config {
    let mut config = Config::new();

    // The `Event` oneof is serialized on the rooms websocket with an internal
    // `type` tag, mirroring the Astarte (Elixir) `SimpleEvents.Encoder` JSON.
    config.type_attribute(".SimpleEvent.event", SERDE_DERIVE);
    config.type_attribute(".SimpleEvent.event", "#[serde(tag = \"type\")]");

    // The `type` tag drops the `_event` suffix (e.g. `device_connected_event`
    // -> `device_connected`), matching the Elixir `SimpleEvents.Encoder`.
    for (field, rename) in [
        ("device_connected_event", "device_connected"),
        ("device_disconnected_event", "device_disconnected"),
        ("incoming_data_event", "incoming_data"),
        ("value_change_event", "value_change"),
        ("value_change_applied_event", "value_change_applied"),
        ("path_created_event", "path_created"),
        ("path_removed_event", "path_removed"),
        ("value_stored_event", "value_stored"),
        ("incoming_introspection_event", "incoming_introspection"),
        ("interface_added_event", "interface_added"),
        ("interface_removed_event", "interface_removed"),
        ("interface_minor_updated_event", "interface_minor_updated"),
        ("device_error_event", "device_error"),
        ("device_registered_event", "device_registered"),
        ("device_deletion_started_event", "device_deletion_started"),
        ("device_deletion_finished_event", "device_deletion_finished"),
    ] {
        config.field_attribute(
            format!(".SimpleEvent.event.{field}"),
            format!("#[serde(rename = \"{rename}\")]"),
        );
    }

    // The events whose proto fields already match the JSON shape only need a
    // serde derive: `value`-less events, device lifecycle and interface events.
    for event in [
        "DeviceConnectedEvent",
        "DeviceDisconnectedEvent",
        "DeviceRegisteredEvent",
        "DeviceDeletionStartedEvent",
        "DeviceDeletionFinishedEvent",
        "DeviceErrorEvent",
        "PathRemovedEvent",
        "InterfaceAddedEvent",
        "InterfaceRemovedEvent",
        "InterfaceMinorUpdatedEvent",
        "InterfaceVersion",
    ] {
        config.type_attribute(event, SERDE_DERIVE);
    }

    config
}

fn main() -> eyre::Result<()> {
    let check_only = std::env::args().any(|arg| arg == "--check");

    let crate_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let proto_root = crate_dir.join("../../../libs/astarte_core");
    let out_path = crate_dir.join(OUT_FILE);

    let tmp = tempfile::tempdir().wrap_err("failed to create temporary output directory")?;

    let mut config = prost_config();
    config.out_dir(tmp.path());
    config
        .compile_protos(
            &["lib/astarte_core/triggers/simple_events/simple_event.proto"],
            &[proto_root
                .to_str()
                .ok_or_else(|| eyre!("proto root not utf-8"))?],
        )
        .wrap_err("failed to compile astarte simple events protos")?;

    // Without an `include_file` stub, prost writes the flattened module content
    // to the default package filename `_.rs`.
    let generated =
        fs::read_to_string(tmp.path().join("_.rs")).wrap_err("failed to read generated output")?;
    let content = generated;

    if check_only {
        let current = fs::read_to_string(&out_path)
            .wrap_err_with(|| format!("failed to read {}", out_path.display()))?;

        if current != content {
            bail!(
                "{} is out of date, run `cargo regen-proto`",
                out_path.display()
            );
        }

        println!("{} is up to date", out_path.display());
    } else {
        fs::write(&out_path, content)
            .wrap_err_with(|| format!("failed to write {}", out_path.display()))?;

        println!("wrote {}", out_path.display());
    }

    Ok(())
}
