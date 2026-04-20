#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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
defmodule Astarte.DataAccess.Generators.Device do
  @moduledoc """
  This module provides generators for Astarte.DataAccess.Device.
  """
  use ExUnitProperties

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device

  alias Astarte.Core.Generators.Device, as: DeviceGenerator

  alias Astarte.DataAccess.Devices.Device, as: DeviceData

  @doc """
  Map the core generator/struct to a data_access one
  """
  @spec from_core(map()) :: StreamData.t(DeviceData.t())
  def from_core(data) when not is_struct(data, StreamData),
    do: data |> constant() |> from_core()

  @spec from_core(StreamData.t(map())) :: StreamData.t(DeviceData.t())
  def from_core(gen) do
    # %{
    #     id: id,
    #     device_id: id,
    #     encoded_id: Device.encode_device_id(id),
    #     connected: last_connection >= last_disconnection,
    #     first_registration: first_registration,
    #     first_credentials_request: first_credentials_request,
    #     last_connection: last_connection,
    #     last_disconnection: last_disconnection,
    #     last_seen_ip: last_seen_ip,
    #     inhibit_credentials_request: inhibit_credentials_request,
    #     last_credentials_request_ip: last_credentials_request_ip,
    #     interfaces_msgs: interfaces_msgs,
    #     interfaces_bytes: interfaces_bytes,
    #     aliases: aliases,
    #     attributes: attributes,
    #     total_received_msgs: total_received_msgs,
    #     total_received_bytes: total_received_bytes
    #   }

    #   @primary_key {:device_id, UUID, autogenerate: false}
    # typed_schema "devices" do
    #   field :aliases, Exandra.Map, key: :string, value: :string
    #   field :attributes, Exandra.Map, key: :string, value: :string
    #   field :cert_aki, :string
    #   field :cert_serial, :string
    #   field :connected, :boolean
    #   field :credentials_secret, :string

    #   field :exchanged_bytes_by_interface, Exandra.Map,
    #     key: Exandra.Tuple,
    #     types: [:string, :integer],
    #     value: :integer

    #   field :exchanged_msgs_by_interface, Exandra.Map,
    #     key: Exandra.Tuple,
    #     types: [:string, :integer],
    #     value: :integer

    #   field :first_credentials_request, DateTimeMs
    #   field :first_registration, DateTimeMs
    #   field :groups, Exandra.Map, key: :string, value: UUID
    #   field :inhibit_credentials_request, :boolean
    #   field :introspection, Exandra.Map, key: :string, value: :integer
    #   field :introspection_minor, Exandra.Map, key: :string, value: :integer
    #   field :last_connection, DateTimeMs
    #   field :last_credentials_request_ip, Exandra.Inet

    #   field :last_disconnection, DateTimeMs
    #   field :last_seen_ip, Exandra.Inet

    #   field :old_introspection,
    #         Exandra.Map,
    #         key: Exandra.Tuple,
    #         types: [:string, :integer],
    #         value: :integer

    #   field :capabilities, Exandra.EmbeddedType, using: Capabilities
    #   field :pending_empty_cache, :boolean
    #   field :protocol_revision, :integer
    #   field :total_received_bytes, :integer
    #   field :total_received_msgs, :integer
    # end

    gen all %{device_id: id} <- gen do
      %DeviceData{
        device_id: id
      }
    end
  end
end
