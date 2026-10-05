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

defmodule Astarte.DataAccess.Database.Migrations.Realm.InitDatabase do
  @moduledoc false

  use Ecto.Migration

  def change do
    create table(:kv_store, primary_key: false) do
      add :group, :string, primary_key: true
      add :key, :string, cluster_key: true
      add :value, :binary
    end

    create table(:names, primary_key: false) do
      add :object_name, :string, primary_key: true
      add :object_type, :int, cluster_key: true
      add :object_uuid, :uuid
    end

    create table(:devices, primary_key: false) do
      add :device_id, :uuid, primary_key: true
      add :aliases, :"map<ascii, varchar>"
      add :introspection, :"map<ascii, int>"
      add :introspection_minor, :"map<ascii, int>"
      add :old_introspection, :"map<frozen<tuple<ascii, int>>, int>"
      add :protocol_revision, :integer
      add :first_registration, :utc_datetime
      add :credentials_secret, :ascii
      add :inhibit_credentials_request, :boolean
      add :cert_serial, :ascii
      add :cert_aki, :ascii
      add :first_credentials_request, :utc_datetime
      add :last_connection, :utc_datetime
      add :last_disconnection, :utc_datetime
      add :connected, :boolean
      add :pending_empty_cache, :boolean
      add :total_received_msgs, :bigint
      add :total_received_bytes, :bigint
      add :last_credentials_request_ip, :inet
      add :last_seen_ip, :inet
    end

    create table(:endpoints, primary_key: false) do
      add :interface_id, :uuid, primary_key: true
      add :endpoint_id, :uuid, cluster_key: true
      add :interface_name, :ascii
      add :interface_major_version, :integer
      add :interface_minor_version, :integer
      add :interface_type, :integer
      add :endpoint, :ascii
      add :value_type, :integer
      add :reliability, :integer
      add :retention, :integer
      add :expiry, :integer
      add :allow_unset, :boolean
      add :explicit_timestamp, :boolean
      add :description, :string
      add :doc, :string
    end

    create table(:interfaces, primary_key: false) do
      add :name, :ascii, primary_key: true
      add :major_version, :integer, cluster_key: true
      add :minor_version, :integer
      add :interface_id, :uuid
      add :storage_type, :integer
      add :storage, :ascii
      add :type, :integer
      add :ownership, :integer
      add :aggregation, :integer
      add :automaton_transitions, :binary
      add :automaton_accepting_states, :binary
      add :description, :string
      add :doc, :string
    end

    create table(:individual_properties, primary_key: false) do
      add :device_id, :uuid, primary_key: true
      add :interface_id, :uuid, primary_key: true
      add :endpoint_id, :uuid, cluster_key: true
      add :path, :string, cluster_key: true
      add :reception_timestamp, :utc_datetime
      add :reception_timestamp_submillis, :smallint

      add :double_value, :double
      add :integer_value, :integer
      add :boolean_value, :boolean
      add :longinteger_value, :bigint
      add :string_value, :string
      add :binaryblob_value, :binary
      add :datetime_value, :utc_datetime
      add :doublearray_value, :"list<double>"
      add :integerarray_value, :"list<int>"
      add :booleanarray_value, :"list<boolean>"
      add :longintegerarray_value, :"list<bigint>"
      add :stringarray_value, :"list<varchar>"
      add :binaryblobarray_value, :"list<blob>"
      add :datetimearray_value, :"list<timestamp>"
    end

    create table(:simple_triggers, primary_key: false) do
      add :object_id, :uuid, primary_key: true
      add :object_type, :integer, primary_key: true
      add :parent_trigger_id, :uuid, cluster_key: true
      add :simple_trigger_id, :uuid, cluster_key: true
      add :trigger_data, :binary
      add :trigger_target, :binary
    end
  end
end
