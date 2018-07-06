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

defmodule Astarte.Pairing.API.Credentials.AstarteMQTTV1.Credentials do
  use Ecto.Schema
  import Ecto.Changeset
  alias Astarte.Pairing.API.Credentials.AstarteMQTTV1.Credentials

  @primary_key false
  embedded_schema do
    field :client_crt, :string
  end

  @doc false
  def changeset(%Credentials{} = verify_request, attrs) do
    verify_request
    |> cast(attrs, [:client_crt])
    |> validate_required([:client_crt])
  end
end
