#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.DataAccess.Devices.Device do
  use TypedEctoSchema
  alias Astarte.DataAccess.UUID
  alias Astarte.DataAccess.DateTime, as: DateTimeMs

  @primary_key {:device_id, UUID, autogenerate: false}
  typed_schema "devices" do
    field :aliases, Exandra.Map, key: :string, value: :string
    field :attributes, Exandra.Map, key: :string, value: :string
    field :cert_aki, :string
    field :cert_serial, :string
    field :connected, :boolean
    field :credentials_secret, :string

    field :exchanged_bytes_by_interface, Exandra.Map,
      key: Exandra.Tuple,
      types: [:string, :integer],
      value: :integer

    field :exchanged_msgs_by_interface, Exandra.Map,
      key: Exandra.Tuple,
      types: [:string, :integer],
      value: :integer

    field :first_credentials_request, DateTimeMs
    field :first_registration, DateTimeMs
    field :groups, Exandra.Map, key: :string, value: UUID
    field :inhibit_credentials_request, :boolean
    field :introspection, Exandra.Map, key: :string, value: :integer
    field :introspection_minor, Exandra.Map, key: :string, value: :integer
    field :last_connection, DateTimeMs
    field :last_credentials_request_ip, Exandra.Inet

    field :last_disconnection, DateTimeMs
    field :last_seen_ip, Exandra.Inet

    field :old_introspection,
          Exandra.Map,
          key: Exandra.Tuple,
          types: [:string, :integer],
          value: :integer

    field :pending_empty_cache, :boolean
    field :protocol_revision, :integer
    field :total_received_bytes, :integer
    field :total_received_msgs, :integer
  end
end
