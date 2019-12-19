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
