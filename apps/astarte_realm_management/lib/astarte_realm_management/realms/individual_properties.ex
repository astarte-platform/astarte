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

# TODO: Copied from astarte_data_access PR #71, see: https://github.com/astarte-platform/astarte_data_access/pull/71
# use `astarte_data_access` when it will be merged
defmodule Astarte.RealmManagement.Realms.IndividualProperty do
  use TypedEctoSchema
  alias Astarte.RealmManagement.UUID
  alias Astarte.RealmManagement.SmallInt
  alias Astarte.RealmManagement.BigInt

  @primary_key false
  typed_schema "individual_properties" do
    field :reception, :utc_datetime_usec, virtual: true
    field :device_id, UUID, primary_key: true
    field :interface_id, UUID, primary_key: true
    field :endpoint_id, UUID, primary_key: true
    field :path, :string, primary_key: true
    field :reception_timestamp, :utc_datetime_usec
    field :reception_timestamp_submillis, SmallInt
    field :double_value, :float
    field :integer_value, :integer
    field :boolean_value, :boolean
    field :longinteger_value, BigInt
    field :string_value, :string
    field :binaryblob_value, :binary
    field :datetime_value, :utc_datetime_usec
    field :doublearray_value, {:array, :float}
    field :integerarray_value, {:array, :integer}
    field :booleanarray_value, {:array, :boolean}
    field :longintegerarray_value, {:array, BigInt}
    field :stringarray_value, {:array, :string}
    field :binaryblobarray_value, {:array, :binary}
    field :datetimearray_value, {:array, :utc_datetime_usec}
  end

  def reception(individual_property) do
    nanos =
      individual_property.reception_timestamp_submillis
      |> Kernel.||(0)
      |> Kernel.*(100)

    individual_property.reception_timestamp
    |> DateTime.add(nanos, :nanosecond)
  end
end
