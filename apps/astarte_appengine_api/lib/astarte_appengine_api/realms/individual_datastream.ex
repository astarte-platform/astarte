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

defmodule Astarte.AppEngine.API.Realms.IndividualDatastream do
  use TypedEctoSchema
  alias Astarte.AppEngine.API.DateTime, as: DateTimeMs
  alias Astarte.AppEngine.API.UUID

  @primary_key false
  typed_schema "individual_datastreams" do
    field :reception, DateTimeMs, virtual: true
    field :device_id, UUID, primary_key: true
    field :interface_id, UUID, primary_key: true
    field :endpoint_id, UUID, primary_key: true
    field :path, :string, primary_key: true
    field :value_timestamp, DateTimeMs, primary_key: true
    field :reception_timestamp, DateTimeMs, primary_key: true
    field :reception_timestamp_submillis, :integer, primary_key: true
    field :binaryblob_value, :binary
    field :binaryblobarray_value, {:array, :binary}
    field :boolean_value, :boolean
    field :booleanarray_value, {:array, :boolean}
    field :datetime_value, DateTimeMs
    field :datetimearray_value, {:array, DateTimeMs}
    field :double_value, :float
    field :doublearray_value, {:array, :float}
    field :integer_value, :integer
    field :integerarray_value, {:array, :integer}
    field :longinteger_value, :integer
    field :longintegerarray_value, {:array, :integer}
    field :string_value, :string
    field :stringarray_value, {:array, :string}
  end

  def prepare_for_db(%{reception: nil} = individual_datastream), do: individual_datastream

  def prepare_for_db(individual_datastream) do
    {reception_ms, submillis} = DateTimeMs.split_submillis(individual_datastream.reception)

    %{
      individual_datastream
      | reception_timestamp: reception_ms,
        reception_timestamp_submillis: submillis
    }
  end
end
