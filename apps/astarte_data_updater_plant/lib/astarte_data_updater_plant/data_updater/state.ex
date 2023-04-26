#
# This file is part of Astarte.
#
# Copyright 2017 - 2023 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.DataUpdaterPlant.DataUpdater.State do
  defstruct [
    :realm,
    :device_id,
    :message_tracker,
    :introspection,
    :groups,
    :interfaces,
    :interface_ids_to_name,
    :interfaces_by_expiry,
    :mappings,
    :paths_cache,
    :device_triggers,
    :data_triggers,
    :volatile_triggers,
    :introspection_triggers,
    :connected,
    :total_received_msgs,
    :total_received_bytes,
    :initial_interface_exchanged_bytes,
    :initial_interface_exchanged_msgs,
    :interface_exchanged_bytes,
    :interface_exchanged_msgs,
    :last_seen_message,
    :last_device_triggers_refresh,
    :last_groups_refresh,
    :datastream_maximum_storage_retention,
    :trigger_id_to_policy_name,
    :discard_messages,
    :last_deletion_in_progress_refresh
  ]
end
