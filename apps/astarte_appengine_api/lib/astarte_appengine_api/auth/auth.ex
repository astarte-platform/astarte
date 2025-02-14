#
# This file is part of Astarte.
#
# Copyright 2018 - 2025 SECO Mind Srl
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

defmodule Astarte.AppEngine.API.Auth do
  alias Astarte.AppEngine.API.Queries
  alias Astarte.DataAccess.Repo

  require Logger

  def fetch_public_key(realm) do
    public_key_query = Queries.fetch_public_key(realm)
    {sql, params} = Repo.to_sql(:all, public_key_query)

    # Equivalent to a `Repo.fetch_one`, but does not raise if we get a Xandra.Error.
    case Repo.query(sql, params) do
      {:ok, %{rows: [[public_key]]}} ->
        {:ok, public_key}

      {:ok, %{num_rows: 0}} ->
        Logger.warning("No public key found in realm #{realm}.", tag: "no_public_key_found")
        {:error, :public_key_not_found}

      {:error, %Xandra.Error{reason: :invalid}} ->
        # TODO: random busy wait here to prevent realm enumeration                 
        Logger.info("Auth request for unexisting realm #{realm}.", tag: "unexisting_realm")
        {:error, :not_existing_realm}
    end
  end
end
