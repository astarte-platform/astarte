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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.RealmManagement.Migrations.CreateDatastreamIndividualMultiInterface do
  use Ecto.Migration

  def up do
    create_if_not_exists table("individual_datastreams", primary_key: false) do
      add :device_id, :uuid, primary_key: true
      add :interface_id, :uuid, primary_key: true
      add :endpoint_id, :uuid, primary_key: true
      add :path, :varchar, primary_key: true
      add :value_timestamp, :timestamp, partition_key: true
      add :reception_timestamp, :timestamp, partition_key: true
      add :reception_timestamp_submillis, :smallint, partition_key: true

      add :double_value, :double
      add :integer_value, :int
      add :boolean_value, :boolean
      add :longinteger_value, :bigint
      add :string_value, :varchar
      add :binaryblob_value, :blob
      add :datetime_value, :timestamp
      add :doublearray_value, :"list<double>"
      add :integerarray_value, :"list<int>"
      add :booleanarray_value, :"list<boolean>"
      add :longintegerarray_value, :"list<bigint>"
      add :stringarray_value, :"list<varchar>"
      add :binaryblobarray_value, :"list<blob>"
      add :datetimearray_value, :"list<timestamp>"
    end
  end
end
