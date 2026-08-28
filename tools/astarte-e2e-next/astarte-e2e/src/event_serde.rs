//! Serde helpers for the prost-generated `simple_events` types.
//!
//! The prost structs use `Option<String>` / `Option<Vec<u8>>` (proto `optional`),
//! while the rooms websocket JSON uses required `interface`/`path` keys and
//! unwrapped BSON `value`/`old_value`/`new_value` keys (mirroring Elixir
//! `SimpleEvents.Encoder`). These `with` modules bridge the two shapes so
//! `regen.rs` can blanket-derive serde and only scope custom behavior to the
//! relevant fields.
//!
//! NB: `with` without `default` on an `Option` field makes a missing key a
//! `missing_field` error (serde#1951). That preserves the current strictness:
//! missing `interface`/`path`/`value` fails, explicit `null` for BSON values
//! maps to absent (matching Elixir `nil <-> nil`).

use serde::{Deserialize, Deserializer, Serialize, Serializer, de::Error as _, ser::Error as _};

pub(crate) fn json_to_bson_value(value: &serde_json::Value) -> eyre::Result<Vec<u8>> {
    bson::serialize_to_vec(&serde_json::json!({ "v": value })).map_err(Into::into)
}

pub(crate) fn bson_value_to_json(bytes: &[u8]) -> eyre::Result<serde_json::Value> {
    if bytes.is_empty() {
        return Ok(serde_json::Value::Null);
    }

    let payload: serde_json::Value = bson::deserialize_from_slice(bytes)?;

    Ok(payload.get("v").cloned().unwrap_or(serde_json::Value::Null))
}

/// Required `Option<String>` fields (`interface`, `path` on BSON events).
///
/// Missing key -> `missing_field` error via derive (no `default`); present
/// `null` -> error below; `None` on serialize -> error (matches the previous
/// hand-written impls).
pub mod required_str {
    use super::*;

    pub fn serialize<S: Serializer>(v: &Option<String>, s: S) -> Result<S::Ok, S::Error> {
        v.as_deref()
            .ok_or_else(|| S::Error::custom("missing required field"))?
            .serialize(s)
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<Option<String>, D::Error> {
        let v =
            Option::<String>::deserialize(d)?.ok_or_else(|| D::Error::missing_field("field"))?;
        Ok(Some(v))
    }
}

/// BSON payload fields, renamed to `value` / `old_value` / `new_value` by the
/// `regen.rs` field attributes.
///
/// Serialize: absent/empty bytes -> JSON `null` (Elixir `nil <-> nil`).
/// Deserialize: missing key -> `missing_field` error via derive; explicit
/// `null` -> `None` (absent, Elixir interop); value -> `Some(bson bytes)`.
pub mod bson_value {
    use super::*;

    pub fn serialize<S: Serializer>(v: &Option<Vec<u8>>, s: S) -> Result<S::Ok, S::Error> {
        let json =
            super::bson_value_to_json(v.as_deref().unwrap_or(&[])).map_err(S::Error::custom)?;
        json.serialize(s)
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<Option<Vec<u8>>, D::Error> {
        let v: Option<serde_json::Value> = Option::deserialize(d)?;
        match v {
            None => Ok(None),
            Some(v) => Ok(Some(
                super::json_to_bson_value(&v).map_err(D::Error::custom)?,
            )),
        }
    }
}
