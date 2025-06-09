#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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
  use TypedStruct

  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Triggers.DataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Mapping
  alias Astarte.DataUpdaterPlant.DataUpdater.Cache
  alias Astarte.DataUpdaterPlant.DataUpdater.CachedPath

  @type interface_name :: String.t()
  @type policy_name :: String.t()
  @type group_name :: String.t()

  @type trigger_id :: binary()
  @type interface_id :: binary()

  @type descriptors_by_name :: %{interface_name => InterfaceDescriptor.t()}

  @type volatile_trigger_key :: {binary(), integer()}

  @type volatile_trigger_value ::
          {{:data_trigger, DataTrigger.t()}, AMQPTriggerTarget.t()}

  @type volatile_triggers_type :: [{volatile_trigger_key(), volatile_trigger_value()}]

  @type endpoint_id :: binary
  @type mappings_map :: %{endpoint_id => Mapping.t()}

  @type interface_major :: non_neg_integer()
  @type interface_key :: {interface_name, interface_major}
  @type interface_exchanged_msgs_map :: %{interface_key => non_neg_integer()}
  @type interface_exchanged_bytes_map :: %{interface_key => non_neg_integer()}

  @type path :: String.t()
  @type paths_cache_key :: {interface_name, path}
  @type paths_cache_type :: Cache.t(paths_cache_key, CachedPath.t())

  @type event_type ::
          :on_device_connection
          | :on_incoming_introspection
          | :on_interface_added
          | {:on_interface_removed, :any_interface}
          | {:on_interface_minor_updated, binary()}
          | :on_device_error
          | :on_empty_cache_received
          | :on_device_disconnection
          | :on_incoming_data
          | :on_value_change
          | :on_value_change_applied
          | :on_path_created
          | :on_path_removed
          | :on_value_stored

  @type data_trigger_key :: {event_type, interface_id, endpoint_id}

  @type device_triggers_type :: %{event_type() => [AMQPTriggerTarget.t()]}

  @type data_triggers_type :: %{data_trigger_key => [DataTrigger.t()]}

  typedstruct do
    @typedoc "State struct"

    field :realm, String.t()
    field :device_id, binary()
    field :message_tracker, pid()
    field :introspection, %{interface_name => interface_major}
    field :groups, [group_name]
    field :interfaces, descriptors_by_name()
    field :interface_ids_to_name, %{interface_id => interface_name}
    field :interfaces_by_expiry, [{integer(), String.t()}]
    field :mappings, mappings_map()
    field :paths_cache, paths_cache_type()
    field :device_triggers, device_triggers_type()
    field :data_triggers, data_triggers_type()
    field :volatile_triggers, volatile_triggers_type()
    field :introspection_triggers, map()
    field :connected, boolean()
    field :total_received_msgs, non_neg_integer()
    field :total_received_bytes, non_neg_integer()
    field :initial_interface_exchanged_bytes, map()
    field :initial_interface_exchanged_msgs, map()
    field :interface_exchanged_bytes, interface_exchanged_bytes_map()
    field :interface_exchanged_msgs, interface_exchanged_msgs_map()
    field :last_seen_message, non_neg_integer()
    field :last_device_triggers_refresh, non_neg_integer()
    field :last_groups_refresh, non_neg_integer()
    field :datastream_maximum_storage_retention, integer() | nil
    field :trigger_id_to_policy_name, %{trigger_id => policy_name}
    field :discard_messages, boolean()
    field :last_deletion_in_progress_refresh, non_neg_integer()
    field :last_datastream_maximum_retention_refresh, non_neg_integer()
  end
end
