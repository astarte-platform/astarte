#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.Pairing.FDO.OwnerKey do
  @moduledoc """
  Owner key lookups used by both the REST and the GraphQL API.
  """

  alias Astarte.Secrets

  @doc """
  Lists the realm's owner key names, grouped by key algorithm.
  """
  @spec list(String.t()) :: {:ok, map()} | {:error, :owner_keys_unavailable}
  def list(realm_name) do
    list_for_key_types(realm_name, Secrets.Core.asymmetric_key_algorithms())
  end

  @doc """
  Lists the realm's owner key names for one key algorithm.
  """
  @spec list(String.t(), String.t()) ::
          {:ok, map()} | {:error, :invalid_key_algorithm | :owner_keys_unavailable}
  def list(realm_name, key_algorithm) do
    with {:ok, key_type} <- key_type(key_algorithm) do
      list_for_key_types(realm_name, [key_type])
    end
  end

  @doc """
  Lists the realm's owner key names for the given key types, e.g. `:es256`.
  """
  @spec list_for_key_types(String.t(), [atom()]) ::
          {:ok, map()} | {:error, :owner_keys_unavailable}
  def list_for_key_types(realm_name, key_types) do
    case Secrets.Core.get_keys(realm_name, key_types) do
      {:ok, keys} -> {:ok, keys}
      _error -> {:error, :owner_keys_unavailable}
    end
  end

  @doc """
  Fetches the owner key named `key_name`.
  """
  @spec fetch(String.t(), String.t(), String.t()) ::
          {:ok, struct()} | {:error, :invalid_key_algorithm | :key_not_found}
  def fetch(realm_name, key_algorithm, key_name) do
    with {:ok, key_type} <- key_type(key_algorithm) do
      case Secrets.Core.find_key(realm_name, key_name, key_type) do
        {:ok, key} -> {:ok, key}
        :not_found -> {:error, :key_not_found}
      end
    end
  end

  defp key_type(key_algorithm) do
    case Secrets.Core.string_to_key_type(key_algorithm) do
      {:ok, key_type} -> {:ok, key_type}
      :error -> {:error, :invalid_key_algorithm}
    end
  end
end
