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

defmodule Astarte.AppEngine.API.Queries do
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult

  def fetch_public_key(client) do
    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT blobAsVarchar(value) FROM kv_store WHERE group='auth' AND key='jwt_public_key_pem'"
      )

    result =
      DatabaseQuery.call!(client, query)
      |> DatabaseResult.head()

    case result do
      ["system.blobasvarchar(value)": public_key] ->
        {:ok, public_key}

      :empty_dataset ->
        {:error, :public_key_not_found}
    end
  end
end
