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

defmodule Astarte.AppEngine.API.Device.InterfaceValuesOptions do
  use Ecto.Schema
  import Ecto.Changeset
  alias Astarte.AppEngine.API.Device.InterfaceValuesOptions

  @primary_key false
  embedded_schema do
    field :since, :utc_datetime
    field :since_after, :utc_datetime
    field :to, :utc_datetime
    field :limit, :integer
    field :downsample_to, :integer
    field :downsample_key, :string
    field :retrieve_metadata, :boolean
    field :allow_bigintegers, :boolean
    field :allow_safe_bigintegers, :boolean
    field :keep_milliseconds, :boolean, default: false
    field :format, :string, default: "structured"
  end

  @doc false
  def changeset(%InterfaceValuesOptions{} = interface_values_request, attrs) do
    cast_attrs = [
      :since,
      :since_after,
      :to,
      :limit,
      :downsample_to,
      :downsample_key,
      :retrieve_metadata,
      :allow_bigintegers,
      :allow_safe_bigintegers,
      :keep_milliseconds,
      :format
    ]

    interface_values_request
    |> cast(attrs, cast_attrs)
    |> validate_mutual_exclusion(:since, :since_after)
    |> validate_number(:limit, greater_than_or_equal_to: 0)
    |> validate_number(:downsample_to, greater_than: 2)
    |> validate_inclusion(:format, ["structured", "table", "disjoint_tables"])
  end

  def validate_mutual_exclusion(changeset, field_a, field_b) do
    changes = Map.get(changeset, :changes)

    if Map.has_key?(changes, field_a) and Map.has_key?(changes, field_b) do
      add_error(changeset, field_b, "conflicts already set parameter", conflits: field_a)
    else
      changeset
    end
  end
end
