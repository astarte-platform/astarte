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

# TODO: Copied from astarte_data_access PR #71, see: https://github.com/astarte-platform/astarte_data_access/pull/71
# use `astarte_data_access` when it will be merged
defmodule Astarte.RealmManagement.Realms.IndividualDatastream do
  use TypedEctoSchema

  @primary_key false
  typed_schema "individual_datastreams" do
    field :device_id, Astarte.DataAccess.UUID, primary_key: true
    field :interface_id, Astarte.DataAccess.UUID, primary_key: true
    field :endpoint_id, Astarte.DataAccess.UUID, primary_key: true
    field :path, :string, primary_key: true
    field :value_timestamp, :utc_datetime_usec, primary_key: true
    field :reception_timestamp, :utc_datetime_usec, primary_key: true
    field :reception_timestamp_submillis, :integer, primary_key: true
    field :binaryblob_value, :binary
    field :binaryblobarray_value, {:array, :binary}
    field :boolean_value, :boolean
    field :booleanarray_value, {:array, :boolean}
    field :datetime_value, :utc_datetime_usec
    field :datetimearray_value, {:array, :utc_datetime_usec}
    field :double_value, :float
    field :doublearray_value, {:array, :float}
    field :integer_value, :integer
    field :integerarray_value, {:array, :integer}
    field :longinteger_value, :integer
    field :longintegerarray_value, {:array, :integer}
    field :string_value, :string
    field :stringarray_value, {:array, :string}
  end
end
