use std::collections::HashMap;
use std::time::Duration;

use astarte_device_sdk::AstarteData;
use chrono::{DateTime, Utc};
use reqwest::{Method, Url};
use serde::de::{Error as _, IgnoredAny, MapAccess, Visitor};
use serde::ser::{Error as _, SerializeMap};
use serde::{Deserialize, Deserializer, Serialize, Serializer};
use serde_with::{DisplayFromStr, DurationMilliSeconds, serde_as};

pub use crate::simple_events::simple_event::Event;
pub use crate::simple_events::{
    DeviceConnectedEvent, DeviceDeletionFinishedEvent, DeviceDeletionStartedEvent,
    DeviceDisconnectedEvent, DeviceErrorEvent, IncomingDataEvent, IncomingIntrospectionEvent,
    InterfaceAddedEvent, InterfaceMinorUpdatedEvent, InterfaceRemovedEvent, InterfaceVersion,
    PathCreatedEvent, PathRemovedEvent, SimpleEvent, ValueChangeAppliedEvent, ValueChangeEvent,
    ValueStoredEvent,
};

#[derive(Debug, Serialize)]
pub struct Trigger {
    pub name: String,
    #[serde(rename = "policy")]
    pub policy_name: Option<String>,
    pub action: TriggerAction,
    pub simple_triggers: Vec<SimpleTrigger>,
}

#[derive(Debug, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum SimpleTrigger {
    DeviceTrigger {
        on: DeviceTriggerCondition,
        #[serde(flatten)]
        target: SimpleTriggerTarget,
    },
    DataTrigger {
        on: DataTriggerCondition,
        #[serde(flatten)]
        target: SimpleTriggerTarget,
        interface_name: String,
        interface_major: u32,
        match_path: String,
        value_match_operator: DataTriggerMatchOperator,
        known_value: AstarteData,
    },
}

#[derive(Debug, Serialize, Clone)]
#[serde(untagged)]
pub enum SimpleTriggerTarget {
    AnyDevice,
    Device { device_id: String },
    Group { group_name: String },
}

#[serde_as]
#[derive(Debug, Serialize, Deserialize, PartialEq)]
#[serde(untagged)]
pub enum TriggerAction {
    HTTPTriggerAction {
        #[serde(rename = "http_url")]
        url: Url,
        #[serde(rename = "http_method")]
        #[serde_as(as = "DisplayFromStr")]
        method: Method,
        #[serde(rename = "http_static_headers")]
        static_headers: HashMap<String, String>,
        ignore_ssl_errors: bool,
        template: Option<String>,
        template_type: Option<String>,
    },
    AMQPTriggerAction {
        #[serde(rename = "amqp_exchange")]
        exchange: String,
        #[serde(rename = "amqp_routing_key")]
        routing_key: String,
        #[serde(rename = "amqp_message_expiration_ms")]
        #[serde_as(serialize_as = "DurationMilliSeconds<u64>")]
        message_expiration: Duration,
        #[serde(rename = "amqp_message_persistent")]
        message_persistent: bool,
        #[serde(rename = "amqp_message_priority")]
        message_priority: Option<u8>,
    },
}

impl TriggerAction {
    pub fn new_http(url: Url, method: Method) -> Self {
        Self::HTTPTriggerAction {
            url,
            method,
            static_headers: HashMap::new(),
            ignore_ssl_errors: false,
            template: None,
            template_type: None,
        }
    }

    pub fn new_amqp(
        exchange: String,
        routing_key: String,
        message_expiration: Duration,
        message_persistent: bool,
    ) -> Self {
        Self::AMQPTriggerAction {
            exchange,
            routing_key,
            message_expiration,
            message_persistent,
            message_priority: None,
        }
    }
}

#[derive(Debug, Serialize, Deserialize, PartialEq)]
pub enum DataTriggerMatchOperator {
    #[serde(rename = "*")]
    AnyValue,
    #[serde(rename = "==")]
    Equals,
    #[serde(rename = "!=")]
    NotEquals,
    #[serde(rename = ">")]
    GreaterThan,
    #[serde(rename = ">=")]
    GreaterThanOrEqualTo,
    #[serde(rename = "<")]
    LessThan,
    #[serde(rename = "<=")]
    LessThanOrEqualTo,
    #[serde(rename = "contains")]
    Contains,
    #[serde(rename = "not_contains")]
    NotContains,
}

#[derive(Debug, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum DataTriggerCondition {
    IncomingData,
    ValueChange,
    ValueChangeApplied,
    PathCreated,
    PathRemoved,
    ValueStored,
}

#[derive(Debug, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum DeviceTriggerCondition {
    DeviceConnected,
    DeviceDisconnected,
    DeviceEmptyCacheReceived,
    DeviceError,
    IncomingIntrospection,
    InterfaceAdded,
    InterfaceRemoved,
    InterfaceMinorUpdated,
    DeviceRegistered,
    DeviceDeletionStarted,
    DeviceDeletionFinished,
}

/// The simplified event pushed on the rooms websocket channel.
///
/// Unlike the protobuf [`SimpleEvent`] used on the AMQP exchange, this payload only carries
/// the device id, the event timestamp and the event itself, with the value already unwrapped
/// from its BSON representation.
#[derive(Debug, Serialize, Deserialize, PartialEq)]
pub struct RoomEvent {
    pub device_id: String,
    pub timestamp: DateTime<Utc>,
    pub event: Event,
}

impl Event {
    pub fn try_into_incoming_data(self) -> Result<IncomingDataEvent, Self> {
        match self {
            Self::IncomingDataEvent(event) => Ok(event),
            other => Err(other),
        }
    }

    pub fn try_into_device_connected(self) -> Result<DeviceConnectedEvent, Self> {
        match self {
            Self::DeviceConnectedEvent(event) => Ok(event),
            other => Err(other),
        }
    }

    pub fn try_into_device_error(self) -> Result<DeviceErrorEvent, Self> {
        match self {
            Self::DeviceErrorEvent(event) => Ok(event),
            other => Err(other),
        }
    }
}

impl IncomingDataEvent {
    pub fn value(&self) -> eyre::Result<serde_json::Value> {
        bson_value_to_json(self.bson_value.as_deref().unwrap_or(&[]))
    }
}

fn json_to_bson_value(value: &serde_json::Value) -> eyre::Result<Vec<u8>> {
    bson::serialize_to_vec(&serde_json::json!({ "v": value })).map_err(Into::into)
}

fn bson_value_to_json(bytes: &[u8]) -> eyre::Result<serde_json::Value> {
    if bytes.is_empty() {
        return Ok(serde_json::Value::Null);
    }

    let payload: serde_json::Value = bson::deserialize_from_slice(bytes)?;

    Ok(payload.get("v").cloned().unwrap_or(serde_json::Value::Null))
}

fn serialize_bson_value_event<S: Serializer>(
    serializer: S,
    interface: &Option<String>,
    path: &Option<String>,
    value: &[u8],
) -> Result<S::Ok, S::Error> {
    let mut map = serializer.serialize_map(None)?;
    map.serialize_entry(
        "interface",
        interface
            .as_deref()
            .ok_or_else(|| S::Error::custom("missing interface"))?,
    )?;
    map.serialize_entry(
        "path",
        path.as_deref()
            .ok_or_else(|| S::Error::custom("missing path"))?,
    )?;
    map.serialize_entry(
        "value",
        &bson_value_to_json(value).map_err(S::Error::custom)?,
    )?;
    map.end()
}

fn serialize_bson_value_change_event<S: Serializer>(
    serializer: S,
    interface: &Option<String>,
    path: &Option<String>,
    old_value: &[u8],
    new_value: &[u8],
) -> Result<S::Ok, S::Error> {
    let mut map = serializer.serialize_map(None)?;
    map.serialize_entry(
        "interface",
        interface
            .as_deref()
            .ok_or_else(|| S::Error::custom("missing interface"))?,
    )?;
    map.serialize_entry(
        "path",
        path.as_deref()
            .ok_or_else(|| S::Error::custom("missing path"))?,
    )?;
    map.serialize_entry(
        "old_value",
        &bson_value_to_json(old_value).map_err(S::Error::custom)?,
    )?;
    map.serialize_entry(
        "new_value",
        &bson_value_to_json(new_value).map_err(S::Error::custom)?,
    )?;
    map.end()
}

impl Serialize for IncomingDataEvent {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        serialize_bson_value_event(
            serializer,
            &self.interface,
            &self.path,
            self.bson_value.as_deref().unwrap_or(&[]),
        )
    }
}

impl Serialize for PathCreatedEvent {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        serialize_bson_value_event(
            serializer,
            &self.interface,
            &self.path,
            self.bson_value.as_deref().unwrap_or(&[]),
        )
    }
}

impl Serialize for ValueStoredEvent {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        serialize_bson_value_event(
            serializer,
            &self.interface,
            &self.path,
            self.bson_value.as_deref().unwrap_or(&[]),
        )
    }
}

impl Serialize for ValueChangeEvent {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        serialize_bson_value_change_event(
            serializer,
            &self.interface,
            &self.path,
            self.old_bson_value.as_deref().unwrap_or(&[]),
            self.new_bson_value.as_deref().unwrap_or(&[]),
        )
    }
}

impl Serialize for ValueChangeAppliedEvent {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        serialize_bson_value_change_event(
            serializer,
            &self.interface,
            &self.path,
            self.old_bson_value.as_deref().unwrap_or(&[]),
            self.new_bson_value.as_deref().unwrap_or(&[]),
        )
    }
}

#[derive(Deserialize)]
struct BsonValueEventParts {
    interface: String,
    path: String,
    value: Option<serde_json::Value>,
    old_value: Option<serde_json::Value>,
    new_value: Option<serde_json::Value>,
}

impl<'de> Deserialize<'de> for IncomingDataEvent {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let parts = BsonValueEventParts::deserialize(deserializer)?;
        let value = parts
            .value
            .ok_or_else(|| D::Error::missing_field("value"))?;

        Ok(Self {
            interface: Some(parts.interface),
            path: Some(parts.path),
            bson_value: Some(json_to_bson_value(&value).map_err(D::Error::custom)?),
        })
    }
}

impl<'de> Deserialize<'de> for PathCreatedEvent {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let parts = BsonValueEventParts::deserialize(deserializer)?;
        let value = parts
            .value
            .ok_or_else(|| D::Error::missing_field("value"))?;

        Ok(Self {
            interface: Some(parts.interface),
            path: Some(parts.path),
            bson_value: Some(json_to_bson_value(&value).map_err(D::Error::custom)?),
        })
    }
}

impl<'de> Deserialize<'de> for ValueStoredEvent {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let parts = BsonValueEventParts::deserialize(deserializer)?;
        let value = parts
            .value
            .ok_or_else(|| D::Error::missing_field("value"))?;

        Ok(Self {
            interface: Some(parts.interface),
            path: Some(parts.path),
            bson_value: Some(json_to_bson_value(&value).map_err(D::Error::custom)?),
        })
    }
}

impl<'de> Deserialize<'de> for ValueChangeEvent {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let parts = BsonValueEventParts::deserialize(deserializer)?;
        let old_value = parts
            .old_value
            .ok_or_else(|| D::Error::missing_field("old_value"))?;
        let new_value = parts
            .new_value
            .ok_or_else(|| D::Error::missing_field("new_value"))?;

        Ok(Self {
            interface: Some(parts.interface),
            path: Some(parts.path),
            old_bson_value: Some(json_to_bson_value(&old_value).map_err(D::Error::custom)?),
            new_bson_value: Some(json_to_bson_value(&new_value).map_err(D::Error::custom)?),
        })
    }
}

impl<'de> Deserialize<'de> for ValueChangeAppliedEvent {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let parts = BsonValueEventParts::deserialize(deserializer)?;
        let old_value = parts
            .old_value
            .ok_or_else(|| D::Error::missing_field("old_value"))?;
        let new_value = parts
            .new_value
            .ok_or_else(|| D::Error::missing_field("new_value"))?;

        Ok(Self {
            interface: Some(parts.interface),
            path: Some(parts.path),
            old_bson_value: Some(json_to_bson_value(&old_value).map_err(D::Error::custom)?),
            new_bson_value: Some(json_to_bson_value(&new_value).map_err(D::Error::custom)?),
        })
    }
}

#[allow(deprecated)]
impl Serialize for IncomingIntrospectionEvent {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        let mut map = serializer.serialize_map(Some(1))?;

        match (&self.introspection, self.introspection_map.is_empty()) {
            (Some(introspection), _) => map.serialize_entry("introspection", introspection)?,
            (None, false) => map.serialize_entry("introspection", &self.introspection_map)?,
            (None, true) => map.serialize_entry("introspection", &serde_json::Value::Null)?,
        }

        map.end()
    }
}

#[allow(deprecated)]
impl<'de> Deserialize<'de> for IncomingIntrospectionEvent {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        #[derive(Deserialize)]
        #[serde(untagged)]
        enum Introspection {
            StringValue(String),
            MapValue(HashMap<String, InterfaceVersion>),
        }

        struct EventVisitor;

        impl<'de> Visitor<'de> for EventVisitor {
            type Value = IncomingIntrospectionEvent;

            fn expecting(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
                formatter.write_str("an incoming introspection event")
            }

            fn visit_map<A: MapAccess<'de>>(self, mut map: A) -> Result<Self::Value, A::Error> {
                let mut introspection = None;
                let mut introspection_map = HashMap::new();

                while let Some(key) = map.next_key::<String>()? {
                    match key.as_str() {
                        "introspection" => match map.next_value::<Introspection>()? {
                            Introspection::StringValue(value) => introspection = Some(value),
                            Introspection::MapValue(value) => introspection_map = value,
                        },
                        _ => {
                            let _ = map.next_value::<IgnoredAny>()?;
                        }
                    }
                }

                Ok(IncomingIntrospectionEvent {
                    introspection,
                    introspection_map,
                })
            }
        }

        deserializer.deserialize_map(EventVisitor)
    }
}

#[cfg(test)]
mod test {
    use std::{collections::HashMap, time::Duration};

    use astarte_device_sdk::AstarteData::Integer;
    use chrono::DateTime;
    use prost::Message;
    use reqwest::{Method, Url};

    use crate::astarte_event::{
        DataTriggerCondition, DataTriggerMatchOperator, DeviceConnectedEvent,
        DeviceTriggerCondition, IncomingDataEvent, RoomEvent, SimpleEvent,
        SimpleTrigger::{DataTrigger, DeviceTrigger},
        SimpleTriggerTarget::{self, AnyDevice},
        Trigger, TriggerAction, ValueChangeEvent, bson_value_to_json, json_to_bson_value,
    };
    use crate::simple_events::simple_event::Event;

    #[test]
    pub fn http_trigger_serialization() {
        let trigger = Trigger {
            name: "some_trigger".into(),
            policy_name: Some("my_policy".into()),
            action: TriggerAction::HTTPTriggerAction {
                url: Url::parse("https://example.com").expect("invalid url in trigger definition"),
                method: Method::POST,
                static_headers: HashMap::from([
                    ("MyHeader".into(), "value".into()),
                    ("AnotherHeader".into(), "anothervalue".into()),
                ]),
                ignore_ssl_errors: true,
                template: Some("some-template".into()),
                template_type: Some("some-template-type".into()),
            },
            simple_triggers: vec![DeviceTrigger {
                on: DeviceTriggerCondition::DeviceRegistered,
                target: AnyDevice,
            }],
        };

        // sort_maps is needed for the hashmap
        insta::with_settings!({ sort_maps => true }, {
            insta::assert_json_snapshot!(trigger);
        });
    }

    #[test]
    pub fn amqp_trigger_serialization() {
        let trigger = Trigger {
            name: "some_trigger".into(),
            policy_name: None,
            action: TriggerAction::AMQPTriggerAction {
                exchange: "some-exchange".into(),
                routing_key: "my-routing-key".into(),
                message_expiration: Duration::from_secs(30),
                message_persistent: true,
                message_priority: None,
            },
            simple_triggers: vec![DataTrigger {
                on: DataTriggerCondition::IncomingData,
                target: SimpleTriggerTarget::Group {
                    group_name: "my-group".into(),
                },
                interface_name: "an.Interface".into(),
                interface_major: 0,
                match_path: "/data".into(),
                value_match_operator: DataTriggerMatchOperator::Equals,
                known_value: Integer(4),
            }],
        };

        insta::assert_json_snapshot!(trigger);
    }

    #[test]
    #[allow(deprecated)]
    fn protobuf_simple_event_roundtrip() {
        let ts = 1787904402000;
        let simple_event = SimpleEvent {
            version: 1,
            simple_trigger_id: None,
            parent_trigger_id: Some(vec![1, 2, 3, 4]),
            realm: Some("test".into()),
            device_id: Some("LrWIo53eSuyhq9Xum5VT3Q".into()),
            timestamp: Some(ts),
            event: Some(Event::DeviceConnectedEvent(DeviceConnectedEvent {
                device_ip_address: Some("192.168.1.1".into()),
            })),
        };

        let mut encoded = Vec::new();
        simple_event.encode(&mut encoded).unwrap();

        let decoded = SimpleEvent::decode(encoded.as_slice()).unwrap();

        assert_eq!(simple_event, decoded);
        assert_eq!(decoded.timestamp, Some(ts));
    }

    #[test]
    fn room_event_serialization() {
        let ts = DateTime::from_timestamp_millis(1787904402000).unwrap();
        let room_event = RoomEvent {
            device_id: "LrWIo53eSuyhq9Xum5VT3Q".into(),
            timestamp: ts,
            event: Event::DeviceConnectedEvent(DeviceConnectedEvent {
                device_ip_address: Some("192.168.1.1".into()),
            }),
        };

        insta::assert_json_snapshot!(room_event);
    }

    #[test]
    fn room_event_deserialization() {
        let json = r#"{
            "device_id": "LrWIo53eSuyhq9Xum5VT3Q",
            "timestamp": "2026-08-28T07:00:02.000000Z",
            "event": {
                "type": "device_connected",
                "device_ip_address": "192.168.1.1"
            }
        }"#;

        let room_event: RoomEvent = serde_json::from_str(json).unwrap();
        let RoomEvent {
            device_id, event, ..
        } = room_event;

        assert_eq!(device_id, "LrWIo53eSuyhq9Xum5VT3Q");
        assert_eq!(
            event,
            Event::DeviceConnectedEvent(DeviceConnectedEvent {
                device_ip_address: Some("192.168.1.1".into()),
            })
        );
    }

    #[test]
    fn incoming_data_room_event_roundtrip() {
        let value = serde_json::json!({ "a": [1, 2, 3], "b": "string", "c": true });
        let event = Event::IncomingDataEvent(IncomingDataEvent {
            interface: Some("com.test.Interface".into()),
            path: Some("/data".into()),
            bson_value: Some(json_to_bson_value(&value).unwrap()),
        });

        let room_event = RoomEvent {
            device_id: "LrWIo53eSuyhq9Xum5VT3Q".into(),
            timestamp: DateTime::from_timestamp_millis(1787904402000).unwrap(),
            event,
        };

        let json = serde_json::to_value(&room_event).unwrap();
        let roundtrip: RoomEvent = serde_json::from_value(json).unwrap();
        let IncomingDataEvent {
            interface,
            path,
            bson_value,
        } = roundtrip.event.try_into_incoming_data().unwrap();

        assert_eq!(interface.as_deref(), Some("com.test.Interface"));
        assert_eq!(path.as_deref(), Some("/data"));
        assert_eq!(
            bson_value_to_json(bson_value.as_deref().unwrap()).unwrap(),
            value
        );
    }

    #[test]
    fn value_change_room_event_roundtrip() {
        let old_value = serde_json::json!(42);
        let new_value = serde_json::json!(43);
        let event = Event::ValueChangeEvent(ValueChangeEvent {
            interface: Some("com.test.Interface".into()),
            path: Some("/data".into()),
            old_bson_value: Some(json_to_bson_value(&old_value).unwrap()),
            new_bson_value: Some(json_to_bson_value(&new_value).unwrap()),
        });

        let room_event = RoomEvent {
            device_id: "LrWIo53eSuyhq9Xum5VT3Q".into(),
            timestamp: DateTime::from_timestamp_millis(1787904402000).unwrap(),
            event,
        };

        let json = serde_json::to_value(&room_event).unwrap();
        let roundtrip: RoomEvent = serde_json::from_value(json).unwrap();

        match roundtrip.event.try_into_incoming_data() {
            Ok(_) => panic!("expected a value change event"),
            Err(Event::ValueChangeEvent(event)) => {
                let ValueChangeEvent {
                    old_bson_value,
                    new_bson_value,
                    ..
                } = event;

                assert_eq!(
                    bson_value_to_json(old_bson_value.as_deref().unwrap()).unwrap(),
                    old_value
                );
                assert_eq!(
                    bson_value_to_json(new_bson_value.as_deref().unwrap()).unwrap(),
                    new_value
                );
            }
            Err(other) => {
                panic!("unexpected event: {other:?}")
            }
        }
    }

    #[test]
    fn bson_value_roundtrip() {
        let value = serde_json::json!({"v": 42});
        let encoded = json_to_bson_value(&value).unwrap();
        assert_eq!(
            bson_value_to_json(&encoded).unwrap().get("v"),
            value.get("v")
        );
    }
}
