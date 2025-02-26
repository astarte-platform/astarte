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

defmodule Astarte.DataUpdaterPlant.DataUpdater.IndividualDatastream do
  use TypedEctoSchema
  alias Astarte.DataUpdaterPlant.DataUpdater.UUID
  alias Astarte.DataUpdaterPlant.DataUpdater.SmallInt
  alias Astarte.DataUpdaterPlant.DataUpdater.BigInt

  @primary_key false
  typed_schema "individual_datastreams" do
    field :device_id, UUID, primary_key: true
    field :interface_id, UUID, primary_key: true
    field :endpoint_id, UUID, primary_key: true
    field :path, :string, primary_key: true

    # We use `utc_datetime_usec`because we're interested in ms, which `utc_datetime` does not provide
    field :value_timestamp, :utc_datetime_usec, primary_key: true
    field :reception_timestamp, :utc_datetime_usec, primary_key: true
    # Ecto does not have a :smallint type
    field :reception_timestamp_submillis, SmallInt, primary_key: true
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
    # Ecto does not have a :bigint type
    field :longinteger_value, BigInt
    field :longintegerarray_value, {:array, BigInt}
    field :string_value, :string
    field :stringarray_value, {:array, :string}
  end
end
