//
// This file is part of Astarte.
//
// Copyright 2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

use std::collections::HashMap;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum DataTriggerCondition {
    IncomingData,
    ValueChange,
    ValueChangeApplied,
    PathCreated,
    PathRemoved,
    ValueStored,
}

#[derive(Debug, Serialize)]
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

#[derive(Debug, Deserialize)]
pub struct SimpleEvent {
    pub device_id: String,
    pub timestamp: DateTime<Utc>,
    pub event: Event,
}

#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Event {
    IncomingData(IncomingData),
    ValueChange(ValueChange),
    ValueChangeApplied(ValueChangeApplied),
    PathCreated(PathCreated),
    PathRemoved(PathRemoved),
    ValueStored(ValueStored),
    DeviceConnected(DeviceConnected),
    DeviceDisconnected(DeviceDisconnected),
    DeviceEmptyCacheReceived(DeviceEmptyCacheReceived),
    DeviceError(DeviceError),
    IncomingIntrospection(IncomingIntrospection),
    InterfaceAdded(InterfaceAdded),
    InterfaceRemoved(InterfaceRemoved),
    InterfaceMinorUpdated(InterfaceMinorUpdated),
    DeviceRegistered(DeviceRegistered),
    DeviceDeletionStarted(DeviceDeletionStarted),
    DeviceDeletionFinished(DeviceDeletionFinished),
}

impl Event {
    pub fn try_into_incoming_data(self) -> Result<IncomingData, Self> {
        if let Self::IncomingData(v) = self {
            Ok(v)
        } else {
            Err(self)
        }
    }

    pub fn try_into_device_error(self) -> Result<DeviceError, Self> {
        if let Self::DeviceError(v) = self {
            Ok(v)
        } else {
            Err(self)
        }
    }

    pub fn try_into_device_connected(self) -> Result<DeviceConnected, Self> {
        if let Self::DeviceConnected(v) = self {
            Ok(v)
        } else {
            Err(self)
        }
    }
}

pub struct InterfaceVersion {
    pub major: i32,
    pub minor: i32,
}

#[derive(Debug, Deserialize)]
pub struct DeviceConnected {
    pub device_ip_address: String,
}
#[derive(Debug, Deserialize)]
pub struct DeviceDisconnected {}

#[derive(Debug, Deserialize)]
pub struct DeviceEmptyCacheReceived {}

#[derive(Debug, Deserialize)]
pub struct DeviceError {
    pub error_name: String,
    pub metadata: HashMap<String, String>,
}

#[derive(Debug, Deserialize)]
pub struct IncomingIntrospection {
    pub introspection: String,
}

#[derive(Debug, Deserialize)]
pub struct InterfaceAdded {
    pub interface: String,
    pub major_version: i32,
    pub minor_version: i32,
}

#[derive(Debug, Deserialize)]
pub struct InterfaceRemoved {
    pub interface: String,
    pub major_version: i32,
}

#[derive(Debug, Deserialize)]
pub struct InterfaceMinorUpdated {
    pub interface: String,
    pub major_version: i32,
    pub old_minor_version: i32,
    pub new_minor_version: i32,
}

#[derive(Debug, Deserialize)]
pub struct DeviceRegistered {}

#[derive(Debug, Deserialize)]
pub struct DeviceDeletionStarted {}

#[derive(Debug, Deserialize)]
pub struct DeviceDeletionFinished {}

#[derive(Debug, Deserialize)]
pub struct IncomingData {
    pub interface: String,
    pub path: String,
    pub value: serde_json::Value,
}

#[derive(Debug, Deserialize)]
pub struct PathCreated {
    pub interface: String,
    pub path: String,
    pub value: serde_json::Value,
}

#[derive(Debug, Deserialize)]
pub struct PathRemoved {
    pub interface: String,
    pub path: String,
}

#[derive(Debug, Deserialize)]
pub struct ValueChange {
    pub interface: String,
    pub path: String,
    pub old_value: serde_json::Value,
    pub new_value: serde_json::Value,
}

#[derive(Debug, Deserialize)]
pub struct ValueStored {
    pub interface: String,
    pub path: String,
    pub value: serde_json::Value,
}

#[derive(Debug, Deserialize)]
pub struct ValueChangeApplied {
    pub interface: String,
    pub path: String,
    pub old_value: serde_json::Value,
    pub new_value: serde_json::Value,
}
