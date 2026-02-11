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

defmodule Astarte.DataAccess.Realms.IndividualProperty do
  @moduledoc """
  This module defines the Ecto schema for the `individual_properties` table.
  """
  use TypedEctoSchema
  alias Astarte.DataAccess.BigInt
  alias Astarte.DataAccess.DateTime, as: DateTimeMs
  alias Astarte.DataAccess.SmallInt
  alias Astarte.DataAccess.UUID

  @primary_key false
  typed_schema "individual_properties" do
    # property reception not present in dup
    field :reception, DateTimeMs, virtual: true
    field :device_id, UUID, primary_key: true
    field :interface_id, UUID, primary_key: true
    field :endpoint_id, UUID, primary_key: true
    field :path, :string, primary_key: true
    field :reception_timestamp, DateTimeMs
    field :reception_timestamp_submillis, SmallInt
    field :double_value, :float
    field :integer_value, :integer
    field :boolean_value, :boolean
    field :longinteger_value, BigInt
    field :string_value, :string
    field :binaryblob_value, :binary
    field :datetime_value, DateTimeMs
    field :doublearray_value, {:array, :float}
    field :integerarray_value, {:array, :integer}
    field :booleanarray_value, {:array, :boolean}
    field :longintegerarray_value, {:array, BigInt}
    field :stringarray_value, {:array, :string}
    field :binaryblobarray_value, {:array, :binary}
    field :datetimearray_value, {:array, DateTimeMs}
  end

  def reception(individual_property) do
    nanos =
      individual_property.reception_timestamp_submillis
      |> Kernel.||(0)
      |> Kernel.*(100)

    individual_property.reception_timestamp
    |> DateTime.add(nanos, :nanosecond)
  end

  def prepare_for_db(%{reception: nil} = individual_property), do: individual_property

  def prepare_for_db(individual_property) do
    {reception_ms, submillis} = DateTimeMs.split_submillis(individual_property.reception)

    %{
      individual_property
      | reception_timestamp: reception_ms,
        reception_timestamp_submillis: submillis
    }
  end
end
