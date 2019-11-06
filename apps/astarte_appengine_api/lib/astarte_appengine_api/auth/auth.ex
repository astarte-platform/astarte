#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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
  alias Astarte.DataAccess.Database

  require Logger

  def fetch_public_key(realm) do
    with {:ok, client} <- Database.connect(realm),
         {:ok, public_key} <- Queries.fetch_public_key(client) do
      {:ok, public_key}
    else
      {:error, :public_key_not_found} ->
        _ = Logger.warn("No public key found in realm #{realm}.", tag: "no_public_key_found")
        {:error, :public_key_not_found}

      {:error, :database_connection_error} ->
        _ = Logger.info("Auth request for unexisting realm #{realm}.", tag: "unexisting_realm")
        # TODO: random busy wait here to prevent realm enumeration
        {:error, :not_existing_realm}
    end
  end
end
