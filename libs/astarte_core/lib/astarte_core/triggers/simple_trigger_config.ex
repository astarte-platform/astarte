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

defmodule Astarte.Core.Triggers.SimpleTriggerConfig do
  @moduledoc """
  This module handles the functions for creating a `SimpleTriggerConfig` and converting it to and from a `TaggedSimpleTrigger`.
  """
  use TypedEctoSchema

  import Ecto.Changeset
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.Group
  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping
  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.Utils, as: SimpleTriggersUtils

  @primary_key false
  typed_embedded_schema do
    # Common
    field :type, :string
    field :on, :string
    field :group_name, :string
    field :device_id, :string
    # Data and Introspection Trigger specific
    field :interface_name, :string
    field :interface_major, :integer
    # Data Trigger specific
    field :match_path, :string
    field :value_match_operator, :string
    field :known_value, :any, virtual: true
  end

  defimpl Jason.Encoder, for: SimpleTriggerConfig do
    def encode(%SimpleTriggerConfig{type: "data_trigger"} = config, options) do
      %{
        "type" => config.type,
        "on" => config.on,
        "interface_name" => config.interface_name,
        "match_path" => config.match_path,
        "value_match_operator" => config.value_match_operator
      }
      |> put_if("known_value", config.known_value, config.value_match_operator != "*")
      |> put_if("interface_major", config.interface_major, config.interface_name != "*")
      |> put_if("group_name", config.group_name, config.group_name != nil)
      |> put_if("device_id", config.device_id, config.device_id != nil)
      |> Jason.Encoder.Map.encode(options)
    end

    def encode(%SimpleTriggerConfig{type: "device_trigger"} = config, options) do
      %{"type" => config.type, "on" => config.on}
      |> put_if("group_name", config.group_name, config.group_name != nil)
      |> put_if("device_id", config.device_id, config.device_id != nil)
      |> Jason.Encoder.Map.encode(options)
    end

    defp put_if(map, key, value, condition) do
      if condition do
        Map.put(map, key, value)
      else
        map
      end
    end
  end

  @data_trigger_permitted_keys [
    :group_name,
    :device_id,
    :type,
    :interface_name,
    :interface_major,
    :on,
    :value_match_operator,
    :match_path,
    :known_value
  ]
  @data_trigger_required_keys [
    :type,
    :interface_name,
    :on,
    :value_match_operator,
    :match_path
  ]
  @data_trigger_condition_to_atom %{
    "incoming_data" => :INCOMING_DATA,
    "value_change" => :VALUE_CHANGE,
    "value_change_applied" => :VALUE_CHANGE_APPLIED,
    "path_created" => :PATH_CREATED,
    "path_removed" => :PATH_REMOVED,
    "value_stored" => :VALUE_STORED
  }
  @data_trigger_condition_to_string %{
    :INCOMING_DATA => "incoming_data",
    :VALUE_CHANGE => "value_change",
    :VALUE_CHANGE_APPLIED => "value_change_applied",
    :PATH_CREATED => "path_created",
    :PATH_REMOVED => "path_removed",
    :VALUE_STORED => "value_stored"
  }
  @data_trigger_operator_to_atom %{
    "*" => :ANY,
    "==" => :EQUAL_TO,
    "!=" => :NOT_EQUAL_TO,
    ">" => :GREATER_THAN,
    ">=" => :GREATER_OR_EQUAL_TO,
    "<" => :LESS_THAN,
    "<=" => :LESS_OR_EQUAL_TO,
    "contains" => :CONTAINS,
    "not_contains" => :NOT_CONTAINS
  }
  @data_trigger_operator_to_string %{
    :ANY => "*",
    :EQUAL_TO => "==",
    :NOT_EQUAL_TO => "!=",
    :GREATER_THAN => ">",
    :GREATER_OR_EQUAL_TO => ">=",
    :LESS_THAN => "<",
    :LESS_OR_EQUAL_TO => "<=",
    :CONTAINS => "contains",
    :NOT_CONTAINS => "not_contains"
  }
  @data_trigger_any_match_operator "*"

  @device_trigger_permitted_keys [
    :type,
    :on,
    :group_name,
    :device_id,
    :interface_name,
    :interface_major
  ]
  @device_trigger_required_keys [
    :type,
    :on
  ]
  @device_trigger_condition_to_atom %{
    "device_connected" => :DEVICE_CONNECTED,
    "device_disconnected" => :DEVICE_DISCONNECTED,
    "device_empty_cache_received" => :DEVICE_EMPTY_CACHE_RECEIVED,
    "device_error" => :DEVICE_ERROR,
    "incoming_introspection" => :INCOMING_INTROSPECTION,
    "interface_added" => :INTERFACE_ADDED,
    "interface_removed" => :INTERFACE_REMOVED,
    "interface_minor_updated" => :INTERFACE_MINOR_UPDATED,
    "device_registered" => :DEVICE_REGISTERED,
    "device_deletion_started" => :DEVICE_DELETION_STARTED,
    "device_deletion_finished" => :DEVICE_DELETION_FINISHED
  }
  @device_trigger_condition_to_string %{
    :DEVICE_CONNECTED => "device_connected",
    :DEVICE_DISCONNECTED => "device_disconnected",
    :DEVICE_EMPTY_CACHE_RECEIVED => "device_empty_cache_received",
    :DEVICE_ERROR => "device_error",
    :INCOMING_INTROSPECTION => "incoming_introspection",
    :INTERFACE_ADDED => "interface_added",
    :INTERFACE_REMOVED => "interface_removed",
    :INTERFACE_MINOR_UPDATED => "interface_minor_updated",
    :DEVICE_REGISTERED => "device_registered",
    :DEVICE_DELETION_STARTED => "device_deletion_started",
    :DEVICE_DELETION_FINISHED => "device_deletion_finished"
  }

  @allowed_trigger_types [
    "data_trigger",
    "device_trigger"
  ]

  @doc false
  def changeset(
        %SimpleTriggerConfig{} = simple_trigger_config,
        %{"type" => "data_trigger"} = params
      ) do
    simple_trigger_config
    |> cast(params, @data_trigger_permitted_keys)
    |> validate_required(@data_trigger_required_keys)
    |> validate_interface()
    |> validate_match_path()
    |> validate_inclusion(:on, Map.keys(@data_trigger_condition_to_atom))
    |> validate_inclusion(:value_match_operator, Map.keys(@data_trigger_operator_to_atom))
    |> validate_device_id(:device_id)
    |> validate_group_name(:group_name)
    |> validate_device_id_xor_group_name()
    |> validate_match_parameters()
  end

  def changeset(
        %SimpleTriggerConfig{} = simple_trigger_config,
        %{"type" => "device_trigger"} = params
      ) do
    simple_trigger_config
    |> cast(params, @device_trigger_permitted_keys)
    |> validate_required(@device_trigger_required_keys)
    |> validate_inclusion(:on, Map.keys(@device_trigger_condition_to_atom))
    |> validate_device_id(:device_id)
    |> validate_group_name(:group_name)
    |> validate_device_id_xor_group_name()
    |> validate_introspection_triggers_interface_match_allowed()
    |> validate_introspection_triggers_interface_version()
    |> validate_introspection_triggers_match_conditions()
  end

  def changeset(%SimpleTriggerConfig{} = simple_trigger_config, params) when is_map(params) do
    # If we're here, "type" is either missing or invalid
    # This will return an error changeset with the appropriate message
    simple_trigger_config
    |> cast(params, [:type])
    |> validate_required([:type])
    |> validate_inclusion(:type, @allowed_trigger_types)
  end

  @doc """
  Creates a `TaggedSimpleTrigger` from a `SimpleTriggerConfig`.

  It is assumed that the `SimpleTriggerConfig` is valid and constructed using `SimpleTriggerConfig.changeset`

  Returns a `%TaggedSimpleTrigger{}`
  """
  def to_tagged_simple_trigger(%SimpleTriggerConfig{type: "data_trigger"} = simple_trigger_config) do
    simple_trigger_config
    |> put_data_trigger_atoms()
    |> create_tagged_data_trigger()
  end

  def to_tagged_simple_trigger(
        %SimpleTriggerConfig{type: "device_trigger"} = simple_trigger_config
      ) do
    simple_trigger_config
    |> put_device_trigger_atoms()
    |> create_tagged_device_trigger()
  end

  def from_tagged_simple_trigger(%TaggedSimpleTrigger{} = tagged_simple_trigger) do
    %TaggedSimpleTrigger{
      object_id: object_id,
      object_type: object_type,
      simple_trigger_container: simple_trigger_container
    } = tagged_simple_trigger

    case simple_trigger_container.simple_trigger do
      {:data_trigger, %DataTrigger{} = data_trigger} ->
        from_data_trigger(data_trigger)

      {:device_trigger, %DeviceTrigger{} = device_trigger} ->
        from_device_trigger(device_trigger, object_id, object_type)
    end
  end

  defp validate_interface(%Ecto.Changeset{} = changeset) do
    if get_field(changeset, :interface_name) == "*" do
      cond do
        get_field(changeset, :on) != "incoming_data" ->
          add_error(changeset, :on, "must be incoming_data when interface_name is *")

        get_field(changeset, :match_path) != "/*" ->
          add_error(changeset, :match_path, "must be /* when interface_name is *")

        true ->
          delete_change(changeset, :interface_major)
      end
    else
      changeset
      |> validate_format(:interface_name, Interface.interface_name_regex())
      |> validate_required([:interface_major])
    end
  end

  defp validate_introspection_triggers_interface_version(%Ecto.Changeset{} = changeset) do
    if allows_interface_match?(changeset) do
      validate_introspection_trigger_interface_name_and_major(changeset)
    else
      changeset
    end
  end

  defp validate_introspection_trigger_interface_name_and_major(%Ecto.Changeset{} = changeset) do
    if get_field(changeset, :interface_name) == "*" do
      delete_change(changeset, :interface_major)
    else
      changeset
      |> validate_format(:interface_name, Interface.interface_name_regex())
      |> validate_required([:interface_major])
    end
  end

  defp validate_introspection_triggers_match_conditions(%Ecto.Changeset{} = changeset) do
    case get_field(changeset, :on) do
      "incoming_introspection" ->
        validate_incoming_introspection_interface_name(changeset)

      "interface_minor_updated" ->
        validate_interface_minor_updated_interface_name(changeset)

      _ ->
        changeset
    end
  end

  defp validate_incoming_introspection_interface_name(%Ecto.Changeset{} = changeset) do
    if get_field(changeset, :interface_name) == nil do
      changeset
    else
      add_error(
        changeset,
        :interface_name,
        "must not be set in incoming_introspection triggers"
      )
    end
  end

  defp validate_interface_minor_updated_interface_name(%Ecto.Changeset{} = changeset) do
    interface_name = get_field(changeset, :interface_name)

    cond do
      interface_name == nil ->
        add_error(
          changeset,
          :interface_name,
          "must be set in interface_minor_updated triggers"
        )

      interface_name == "*" ->
        add_error(
          changeset,
          :interface_name,
          "must not be '*' in interface_minor_updated triggers"
        )

      true ->
        changeset
    end
  end

  defp validate_match_path(%Ecto.Changeset{} = changeset) do
    if get_field(changeset, :match_path) == "/*" do
      if get_field(changeset, :value_match_operator) != "*" do
        add_error(changeset, :value_match_operator, "must be * when match_path is /*")
      else
        changeset
      end
    else
      validate_format(changeset, :match_path, Mapping.mapping_regex())
    end
  end

  defp validate_match_parameters(%Ecto.Changeset{} = changeset) do
    if get_field(changeset, :value_match_operator, "*") == @data_trigger_any_match_operator do
      changeset
      |> delete_change(:known_value)
    else
      changeset
      |> validate_required([:known_value])
    end
  end

  defp validate_device_id(%Ecto.Changeset{} = changeset, field) do
    validate_change(changeset, field, fn field, encoded_id ->
      case validate_device_id_or_any(encoded_id) do
        :ok ->
          []

        {:error, :invalid_device_id} ->
          # decode_device_id failed
          [{field, "is not a valid device id"}]

        {:error, :extended_id_not_allowed} ->
          # extended id
          [{field, "is too long, device id must be 128 bits"}]
      end
    end)
  end

  defp validate_device_id_or_any("*"), do: :ok

  defp validate_device_id_or_any(encoded_id) do
    with {:ok, _decoded_id} <- Device.decode_device_id(encoded_id) do
      :ok
    end
  end

  defp validate_group_name(%Ecto.Changeset{} = changeset, field) do
    validate_change(changeset, field, fn field, group_name ->
      if Group.valid_name?(group_name) do
        []
      else
        [{field, "is not valid"}]
      end
    end)
  end

  defp validate_device_id_xor_group_name(%Ecto.Changeset{} = changeset) do
    with {source, device_id} when source in [:changes, :data] and device_id != nil <-
           fetch_field(changeset, :device_id),
         {source, group_name} when source in [:changes, :data] and group_name != nil <-
           fetch_field(changeset, :group_name) do
      add_error(changeset, :group_name, "must not be defined if device_id is defined")
    else
      _ ->
        # At least one of the two is not set
        changeset
    end
  end

  defp validate_introspection_triggers_interface_match_allowed(%Ecto.Changeset{} = changeset) do
    if get_field(changeset, :interface_name) != nil and not allows_interface_match?(changeset) do
      add_error(
        changeset,
        :interface_name,
        "is allowed only in if 'on' is one of interface_minor_updated, interface_removed, interface_added"
      )
    else
      changeset
    end
  end

  defp allows_interface_match?(%Ecto.Changeset{} = changeset) do
    Enum.member?(
      ["interface_minor_updated", "interface_removed", "interface_added"],
      get_field(changeset, :on)
    )
  end

  defp put_data_trigger_atoms(%{on: condition, value_match_operator: operator} = params) do
    condition_atom = Map.get(@data_trigger_condition_to_atom, condition)
    operator_atom = Map.get(@data_trigger_operator_to_atom, operator)
    %{params | on: condition_atom, value_match_operator: operator_atom}
  end

  defp put_device_trigger_atoms(%{on: condition} = params) do
    condition_atom = Map.get(@device_trigger_condition_to_atom, condition)
    %{params | on: condition_atom}
  end

  defp create_tagged_data_trigger(%SimpleTriggerConfig{} = config) do
    %SimpleTriggerConfig{
      device_id: device_id,
      group_name: group_name,
      interface_name: interface_name,
      interface_major: interface_major,
      match_path: match_path,
      known_value: known_value,
      on: trigger_type,
      value_match_operator: value_match_operator
    } = config

    {object_id, object_type} = get_data_trigger_object(config)

    data_trigger = %DataTrigger{
      device_id: device_id,
      group_name: group_name,
      interface_name: interface_name,
      interface_major: interface_major,
      known_value: known_value && Cyanide.encode!(%{v: known_value}),
      match_path: match_path,
      data_trigger_type: trigger_type,
      value_match_operator: value_match_operator
    }

    %TaggedSimpleTrigger{
      object_type: object_type,
      object_id: object_id,
      simple_trigger_container: %SimpleTriggerContainer{
        simple_trigger: {:data_trigger, data_trigger}
      }
    }
  end

  defp get_data_trigger_object(%SimpleTriggerConfig{} = config) do
    %SimpleTriggerConfig{
      device_id: device_id,
      group_name: group_name,
      interface_name: interface_name,
      interface_major: interface_major
    } = config

    cond do
      is_binary(device_id) and device_id != "*" ->
        get_data_trigger_object_for_device(device_id, interface_name, interface_major)

      is_binary(group_name) and Group.valid_name?(group_name) ->
        get_data_trigger_object_for_group(group_name, interface_name, interface_major)

      # Any interface
      interface_name == "*" ->
        any_interface_id = SimpleTriggersUtils.any_interface_object_id()
        {any_interface_id, SimpleTriggersUtils.object_type_to_int!(:any_interface)}

      # Specific interface
      is_binary(interface_name) and is_integer(interface_major) ->
        interface_id = CQLUtils.interface_id(interface_name, interface_major)
        {interface_id, SimpleTriggersUtils.object_type_to_int!(:interface)}
    end
  end

  defp get_data_trigger_object_for_device(device_id, interface_name, interface_major) do
    cond do
      interface_name == "*" ->
        {:ok, decoded_device_id} = Device.decode_device_id(device_id)
        object_id = SimpleTriggersUtils.get_device_and_any_interface_object_id(decoded_device_id)
        {object_id, SimpleTriggersUtils.object_type_to_int!(:device_and_any_interface)}

      is_binary(interface_name) and is_integer(interface_major) ->
        {:ok, decoded_device_id} = Device.decode_device_id(device_id)
        interface_id = CQLUtils.interface_id(interface_name, interface_major)

        object_id =
          SimpleTriggersUtils.get_device_and_interface_object_id(decoded_device_id, interface_id)

        {object_id, SimpleTriggersUtils.object_type_to_int!(:device_and_interface)}
    end
  end

  defp get_data_trigger_object_for_group(group_name, interface_name, interface_major) do
    cond do
      interface_name == "*" ->
        object_id = SimpleTriggersUtils.get_group_and_any_interface_object_id(group_name)
        {object_id, SimpleTriggersUtils.object_type_to_int!(:group_and_any_interface)}

      is_binary(interface_name) and is_integer(interface_major) ->
        interface_id = CQLUtils.interface_id(interface_name, interface_major)

        object_id =
          SimpleTriggersUtils.get_group_and_interface_object_id(group_name, interface_id)

        {object_id, SimpleTriggersUtils.object_type_to_int!(:group_and_interface)}
    end
  end

  defp create_tagged_device_trigger(%SimpleTriggerConfig{} = config) do
    %SimpleTriggerConfig{
      device_id: device_id,
      group_name: group_name,
      on: event_type,
      # these fields are nil if it is not an introspection trigger
      interface_name: interface_name,
      interface_major: interface_major
    } = config

    {object_id, object_type} = get_device_trigger_object(config)

    device_trigger = %DeviceTrigger{
      device_id: device_id,
      group_name: group_name,
      device_event_type: event_type,
      interface_name: interface_name,
      interface_major: interface_major
    }

    %TaggedSimpleTrigger{
      object_type: object_type,
      object_id: object_id,
      simple_trigger_container: %SimpleTriggerContainer{
        simple_trigger: {:device_trigger, device_trigger}
      }
    }
  end

  defp get_device_trigger_object(%SimpleTriggerConfig{} = config) do
    %SimpleTriggerConfig{
      device_id: device_id,
      group_name: group_name
    } = config

    cond do
      # Device specific
      is_binary(device_id) and device_id != "*" ->
        {:ok, decoded_device_id} = Device.decode_device_id(device_id)
        {decoded_device_id, SimpleTriggersUtils.object_type_to_int!(:device)}

      # Group specific
      is_binary(group_name) and Group.valid_name?(group_name) ->
        group_id = SimpleTriggersUtils.get_group_object_id(group_name)
        {group_id, SimpleTriggersUtils.object_type_to_int!(:group)}

      # Any device
      device_id == "*" or device_id == nil ->
        any_device_id = SimpleTriggersUtils.any_device_object_id()
        {any_device_id, SimpleTriggersUtils.object_type_to_int!(:any_device)}
    end
  end

  defp from_data_trigger(%DataTrigger{} = data_trigger) do
    %DataTrigger{
      data_trigger_type: data_trigger_type,
      group_name: group_name,
      device_id: device_id,
      interface_name: interface_name,
      interface_major: interface_major,
      value_match_operator: value_match_operator,
      match_path: match_path,
      known_value: known_value
    } = data_trigger

    condition = Map.fetch!(@data_trigger_condition_to_string, data_trigger_type)

    value_match_operator_string =
      Map.fetch!(@data_trigger_operator_to_string, value_match_operator)

    decoded_known_value =
      if known_value do
        Cyanide.decode!(known_value)
        |> Map.get("v")
      else
        nil
      end

    # TODO: interface_name and interface_major can't be deducted from interface_id,
    # leaving them nil waiting for an API to retrieve them
    %SimpleTriggerConfig{
      type: "data_trigger",
      on: condition,
      device_id: normalize_proto_string_default(device_id),
      group_name: normalize_proto_string_default(group_name),
      interface_name: interface_name,
      interface_major: interface_major,
      value_match_operator: value_match_operator_string,
      match_path: match_path,
      known_value: decoded_known_value
    }
  end

  defp from_device_trigger(%DeviceTrigger{} = device_trigger, object_id, object_type) do
    %DeviceTrigger{
      group_name: group_name,
      device_id: inner_device_id,
      device_event_type: device_event_type,
      # those field are nil if it is not an introspection trigger
      interface_name: interface_name,
      interface_major: interface_major
    } = device_trigger

    condition = Map.fetch!(@device_trigger_condition_to_string, device_event_type)

    # Allow backwards compatibility with triggers where the device_id was not saved
    # in the DeviceTrigger but was used as object id
    device_id =
      cond do
        is_binary(inner_device_id) and inner_device_id != "" ->
          inner_device_id

        object_type == SimpleTriggersUtils.object_type_to_int!(:device) ->
          Device.encode_device_id(object_id)

        # This also covers triggers installed with * as device_id
        true ->
          nil
      end

    %SimpleTriggerConfig{
      type: "device_trigger",
      on: condition,
      device_id: device_id,
      group_name: normalize_proto_string_default(group_name),
      # those field are nil if it is not an introspection trigger
      interface_name: interface_name,
      interface_major: interface_major
    }
  end

  defp normalize_proto_string_default(string) do
    if string == "" do
      nil
    else
      string
    end
  end
end
