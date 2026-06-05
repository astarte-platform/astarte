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

defmodule Astarte.DataUpdaterPlant.DataEncryptionKeyCache do
  @moduledoc """
  Module implementing caching logic for Data Encryption Keys (DEKs).
  It takes care of the retrieval of the DEKs when missing or expired,
  and returns a valid DEK if present or an error if the DEK retrieval failed.
  """

  alias Astarte.Secrets
  alias Astarte.Secrets.Core

  @dek_cache_name :data_encryption_keys
  @dek_cache_ttl Application.compile_env(:astarte_data_updater_plant, :dek_cache_ttl_seconds)
  @kek_key_name "realm_kek"

  @spec init_options() :: list()
  def init_options do
    [
      name: @dek_cache_name,
      ttl_check_interval: :timer.seconds(1),
      global_ttl: :timer.seconds(@dek_cache_ttl)
    ]
  end

  @spec fetch_data_encryption_key(String.t()) :: {:ok, map()} | {:error, atom()}
  def fetch_data_encryption_key(realm_name) do
    ConCache.fetch_or_store(@dek_cache_name, realm_name, fn ->
      generate_and_store_new_dek(realm_name)
    end)
  end

  defp generate_and_store_new_dek(realm_name) do
    namespace = Core.realm_kek_namespace_tokens(realm_name) |> Path.join()

    case Secrets.generate_dek(@kek_key_name, namespace) do
      {:ok, _dek} = dek_entry -> dek_entry
      _ -> {:error, :dek_generation_error}
    end
  end

  @spec reset_realm_dek(String.t()) :: :ok
  def reset_realm_dek(realm_name) do
    ConCache.delete(@dek_cache_name, realm_name)
  end
end
