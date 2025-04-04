#
# This file is part of Astarte.
#
# Copyright 2018-2025 SECO Mind Srl
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

defmodule Astarte.Pairing.API.CredentialsSecret.Cache do
  @moduledoc """
  This module caches an association between the sha256 of a
  credentials_secret and its stored bcrypt hash to save some
  computation time
  """

  @max_keys 32768

  use Agent

  def start_link(_args) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc """
  Adds an association between a sha256 hash and a bcrypt hash
  """
  def put(sha_hash, bcrypt_hash) do
    Agent.update(__MODULE__, fn cache ->
      if Map.has_key?(cache, sha_hash) do
        Map.put(cache, sha_hash, bcrypt_hash)
      else
        cache
        |> limit_map_size(@max_keys)
        |> Map.put(sha_hash, bcrypt_hash)
      end
    end)
  end

  @doc """
  Gets the bcrypt hash for a given sha hash.
  Returns `{:ok, bcrypt_hash}` if it's present, :error if it's not
  """
  def fetch(sha_hash) do
    Agent.get(__MODULE__, &Map.fetch(&1, sha_hash))
  end

  defp limit_map_size(map, max_size) when map_size(map) >= max_size do
    {key, _val} = Enum.random(map)
    Map.delete(map, key)
  end

  defp limit_map_size(map, _max_size) do
    map
  end

  if Mix.env() == :test do
    def flush do
      Agent.update(__MODULE__, fn _ -> %{} end)
    end
  end
end
