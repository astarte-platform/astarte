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
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.AppEngine.API.Device.DevicesListOptions do
  use Ecto.Schema
  import Ecto.Changeset
  alias Astarte.AppEngine.API.Device.DevicesListOptions

  @primary_key false
  embedded_schema do
    field :from_token, :integer, default: nil
    field :limit, :integer, default: 1000
    field :details, :boolean, default: false
  end

  @doc false
  def changeset(%DevicesListOptions{} = devices_list_request, attrs) do
    cast_attrs = [
      :from_token,
      :limit,
      :details
    ]

    devices_list_request
    |> cast(attrs, cast_attrs)
    |> validate_number(:limit, greater_than: 0)
  end
end
