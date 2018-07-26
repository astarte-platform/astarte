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

defmodule Astarte.Pairing.CredentialsSecret.Cache do
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
