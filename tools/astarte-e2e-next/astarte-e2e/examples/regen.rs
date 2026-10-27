//! Regenerator for the prost types generated from the Astarte `simple_events`
//! protos, used through the `regen-proto` cargo alias:
//!
//! ```sh
//! cargo regen-proto           # write src/simple_events.rs
//! cargo regen-proto --check   # fail if src/simple_events.rs is out of date
//! ```

use std::fs;
use std::path::{Path, PathBuf};

use eyre::{Context, bail, eyre};
use prost_build::Config;

const SERDE_DERIVE: &str = "#[derive(::serde::Serialize)] #[derive(::serde::Deserialize)]";

const OUT_FILE: &str = "src/simple_events.rs";
const SIMPLE_EVENT_PROTO: &str = "lib/astarte_core/triggers/simple_events/simple_event.proto";

/// Message types with hand-written serde impls in `crate::astarte_event`.
///
/// Everything else gets a plain serde derive (plus field-level `with`
/// helpers for BSON events, see below). Keep this list explicit so a new
/// merge-style event fails review rather than silently deriving the wrong
/// JSON shape.
const SERDE_DENYLIST: &[&str] = &["IncomingIntrospectionEvent"];

/// BSON payload events: proto `bson_value` bytes map to unwrapped JSON
/// `value` (and `old/new_bson_value` to `old/new_value`), mirroring Elixir
/// `SimpleEvents.Encoder`. `interface`/`path` stay required via
/// `event_serde::required_str`.
const BSON_SINGLE_VALUE_EVENTS: &[&str] =
    &["IncomingDataEvent", "PathCreatedEvent", "ValueStoredEvent"];

const BSON_CHANGE_EVENTS: &[&str] = &["ValueChangeEvent", "ValueChangeAppliedEvent"];

/// Parse `(message_type, field_name)` pairs from the `oneof event { ... }`
/// block of `simple_event.proto`.
fn parse_oneof_events(proto_file: &Path) -> eyre::Result<Vec<(String, String)>> {
    let content = fs::read_to_string(proto_file)
        .wrap_err_with(|| format!("failed to read {}", proto_file.display()))?;

    let oneof_start = content
        .find("oneof event")
        .ok_or_else(|| eyre!("`oneof event` block not found in {}", proto_file.display()))?;
    let brace_start = content[oneof_start..]
        .find('{')
        .ok_or_else(|| eyre!("malformed `oneof event` block"))?
        + oneof_start;
    let brace_end = content[brace_start..]
        .find('}')
        .ok_or_else(|| eyre!("malformed `oneof event` block"))?
        + brace_start;
    let block = &content[brace_start + 1..brace_end];

    let mut events = Vec::new();
    for line in block.lines() {
        // Strip `//` comments and whitespace.
        let line = line.split("//").next().unwrap_or("").trim();
        if line.is_empty() {
            continue;
        }
        // Expected shape: `DeviceConnectedEvent device_connected_event = 6;`
        let line = line.strip_suffix(';').unwrap_or(line).trim();
        let mut parts = line.split_whitespace();
        let ty = parts.next();
        let field = parts.next();
        match (ty, field) {
            (Some(ty), Some(field)) => events.push((ty.to_string(), field.to_string())),
            _ => bail!("malformed oneof entry: `{line}`"),
        }
    }

    if events.is_empty() {
        bail!("no events found in `oneof event` block");
    }

    Ok(events)
}

fn prost_config(proto_file: &Path) -> eyre::Result<Config> {
    let mut config = Config::new();

    // The `Event` oneof is serialized on the rooms websocket with an internal
    // `type` tag, mirroring the Astarte (Elixir) `SimpleEvents.Encoder` JSON.
    config.type_attribute(".SimpleEvent.event", SERDE_DERIVE);
    config.type_attribute(".SimpleEvent.event", "#[serde(tag = \"type\")]");

    let events = parse_oneof_events(proto_file)?;

    for (ty, field) in &events {
        // The `type` tag drops the `_event` suffix (e.g.
        // `device_connected_event` -> `device_connected`), matching the Elixir
        // `SimpleEvents.Encoder`. All oneof fields must follow this convention.
        let rename = field
            .strip_suffix("_event")
            .ok_or_else(|| eyre!("oneof field `{field}` does not end with `_event`"))?;
        config.field_attribute(
            format!(".SimpleEvent.event.{field}"),
            format!("#[serde(rename = \"{rename}\")]"),
        );

        // Plain serde derive for everything except types with hand-written
        // impls. New empty/lifecycle events are picked up automatically.
        if !SERDE_DENYLIST.contains(&ty.as_str()) {
            config.type_attribute(ty, SERDE_DERIVE);
        }
    }

    // `InterfaceVersion` is not part of the oneof but is embedded in the
    // introspection map, which is serialized through serde.
    config.type_attribute("InterfaceVersion", SERDE_DERIVE);

    // BSON events keep their struct-level derive (added above) and get
    // field-level shape adapters. `with` without `default` keeps missing keys
    // a `missing_field` error, preserving the previous strictness.
    for msg in BSON_SINGLE_VALUE_EVENTS
        .iter()
        .chain(BSON_CHANGE_EVENTS.iter())
    {
        config.field_attribute(
            format!("{msg}.interface"),
            "#[serde(with = \"crate::event_serde::required_str\")]",
        );
        config.field_attribute(
            format!("{msg}.path"),
            "#[serde(with = \"crate::event_serde::required_str\")]",
        );
    }
    for msg in BSON_SINGLE_VALUE_EVENTS {
        config.field_attribute(
            format!("{msg}.bson_value"),
            "#[serde(rename = \"value\", with = \"crate::event_serde::bson_value\")]",
        );
    }
    for msg in BSON_CHANGE_EVENTS {
        config.field_attribute(
            format!("{msg}.old_bson_value"),
            "#[serde(rename = \"old_value\", with = \"crate::event_serde::bson_value\")]",
        );
        config.field_attribute(
            format!("{msg}.new_bson_value"),
            "#[serde(rename = \"new_value\", with = \"crate::event_serde::bson_value\")]",
        );
    }

    Ok(config)
}

fn main() -> eyre::Result<()> {
    let check_only = std::env::args().any(|arg| arg == "--check");

    let crate_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let proto_root = crate_dir.join("../../../apps/astarte_core");
    let proto_file = proto_root.join(SIMPLE_EVENT_PROTO);
    let out_path = crate_dir.join(OUT_FILE);

    let tmp = tempfile::tempdir().wrap_err("failed to create temporary output directory")?;

    let mut config = prost_config(&proto_file)?;
    config.out_dir(tmp.path());
    config
        .compile_protos(
            &[SIMPLE_EVENT_PROTO],
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
