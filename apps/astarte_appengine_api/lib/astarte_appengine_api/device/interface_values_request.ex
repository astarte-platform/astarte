#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.AppEngine.API.Device.InterfaceValuesRequest  do
  use Ecto.Schema
  import Ecto.Changeset
  alias Astarte.AppEngine.API.Device.InterfaceValuesRequest

  @primary_key false
  embedded_schema do
    field :since, :utc_datetime
    field :since_after, :utc_datetime
    field :to, :utc_datetime
    field :limit, :integer
    field :retrieve_metadata, :boolean
    field :allow_bigintegers, :boolean
    field :allow_safe_bigintegers, :boolean
    field :keep_milliseconds, :boolean, default: false
    field :format, :string, default: "structured"
  end

  @doc false
  def changeset(%InterfaceValuesRequest{} = interface_values_request, attrs) do
    cast_attrs = [
      :since,
      :since_after,
      :to,
      :limit,
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
