#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.Core.Triggers.SimpleTriggersProtobuf.Utils do
  @moduledoc """
  Utility functions for working with SimpleTriggersProtobuf structures.
  """

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Mapping
  alias Astarte.Core.Triggers.DataTrigger

  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger,
    as: SimpleTriggersProtobufDataTrigger

  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer

  @any_device_object_id <<140, 77, 4, 17, 75, 202, 11, 92, 131, 72, 15, 167, 65, 149, 191, 244>>
  @any_interface_object_id <<247, 238, 60, 243, 184, 175, 236, 43, 25, 242, 126, 91, 253, 141, 17,
                             119>>
  @groups_namespace <<36, 234, 86, 36, 135, 212, 64, 186, 187, 188, 84, 47, 123, 78, 154, 123>>
  @device_object_type_int 1
  @interface_object_type_int 2
  @any_interface_object_type_int 3
  @any_device_object_type_int 4
  @group_object_type_int 5
  @group_and_interface_object_type_int 6
  @device_and_interface_object_type_int 7
  @group_and_any_interface_object_type_int 8
  @device_and_any_interface_object_type_int 9

  def any_interface_object_id do
    @any_interface_object_id
  end

  def any_device_object_id do
    @any_device_object_id
  end

  def object_type_to_int!(:device), do: @device_object_type_int
  def object_type_to_int!(:interface), do: @interface_object_type_int
  def object_type_to_int!(:any_device), do: @any_device_object_type_int
  def object_type_to_int!(:any_interface), do: @any_interface_object_type_int
  def object_type_to_int!(:group), do: @group_object_type_int
  def object_type_to_int!(:group_and_interface), do: @group_and_interface_object_type_int
  def object_type_to_int!(:device_and_interface), do: @device_and_interface_object_type_int
  def object_type_to_int!(:group_and_any_interface), do: @group_and_any_interface_object_type_int

  def object_type_to_int!(:device_and_any_interface),
    do: @device_and_any_interface_object_type_int

  def deserialize_trigger_target(payload) do
    %TriggerTargetContainer{
      trigger_target: {_target_type, target}
    } = TriggerTargetContainer.decode(payload)

    target
  end

  def deserialize_simple_trigger(payload) do
    %SimpleTriggerContainer{
      simple_trigger: {simple_trigger_type, simple_trigger}
    } = SimpleTriggerContainer.decode(payload)

    {simple_trigger_type, simple_trigger}
  end

  def get_interface_id_or_any(interface_name, interface_major) do
    if interface_name == "*" do
      :any_interface
    else
      CQLUtils.interface_id(interface_name, interface_major)
    end
  end

  def get_group_object_id(group_name) when is_binary(group_name) do
    UUID.uuid5(@groups_namespace, group_name, :raw)
  end

  def get_device_and_any_interface_object_id(device_id) when is_binary(device_id) do
    UUID.uuid5(@any_device_object_id, device_id, :raw)
  end

  def get_group_and_any_interface_object_id(group_name) when is_binary(group_name) do
    UUID.uuid5(@any_device_object_id, group_name, :raw)
  end

  def get_device_and_interface_object_id(device_id, interface_id)
      when is_binary(device_id) and is_binary(interface_id) do
    UUID.uuid5(interface_id, device_id, :raw)
  end

  def get_group_and_interface_object_id(group_name, interface_id)
      when is_binary(group_name) and is_binary(interface_id) do
    UUID.uuid5(interface_id, group_name, :raw)
  end

  def simple_trigger_to_data_trigger(protobuf_data_trigger) do
    %SimpleTriggersProtobufDataTrigger{
      interface_name: interface_name,
      interface_major: interface_major,
      match_path: match_path,
      value_match_operator: value_match_operator,
      known_value: encoded_known_value
    } = protobuf_data_trigger

    value_match_operator =
      if value_match_operator == :INVALID_OPERATOR do
        :ANY
      else
        value_match_operator
      end

    %{"v" => plain_value} =
      if encoded_known_value do
        Cyanide.decode!(encoded_known_value)
      else
        %{"v" => nil}
      end

    path_match_tokens =
      if match_path == "/*" do
        :any_endpoint
      else
        match_path
        |> Mapping.normalize_endpoint()
        |> String.split("/")
        |> tl()
      end

    interface_id_or_any = get_interface_id_or_any(interface_name, interface_major)

    %DataTrigger{
      interface_id: interface_id_or_any,
      path_match_tokens: path_match_tokens,
      value_match_operator: value_match_operator,
      known_value: plain_value,
      trigger_targets: nil
    }
  end
end
