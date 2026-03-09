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

defmodule Astarte.Pairing.FDO.OpenBao do
  @moduledoc """
  Functionality to interface with OpenBao APIs.
  """

  alias Astarte.Pairing.FDO.OpenBao.{Client, Core}

  require Logger

  def create_namespace(realm_name, user_id \\ nil, key_algorithm) do
    with {:ok, namespace} <-
           Core.namespace_tokens(realm_name, user_id, key_algorithm)
           |> Core.create_nested_namespace() do
      Core.mount_transit_engine(namespace)
      {:ok, namespace}
    end
  end

  def list_namespaces do
    with {:ok, namespaces} <- Core.list_namespaces() do
      {:ok, Enum.to_list(namespaces)}
    end
  end

  @spec create_keypair(String.t(), Core.key_algorithm(), list()) ::
          {:ok, map()} | {:error, Jason.DecodeError.t()} | :error
  def create_keypair(key_name, key_type, options \\ []) do
    namespace = Keyword.fetch!(options, :namespace)
    allow_key_export_and_backup = Keyword.get(options, :allow_key_export_and_backup, false)

    with {:ok, key_type_string} <- Core.key_type_to_string(key_type) do
      Core.create_keypair(key_name, key_type_string, allow_key_export_and_backup, namespace)
    end
  end

  @spec enable_key_deletion(String.t(), list()) :: :ok | :error
  def enable_key_deletion(key_name, options \\ []) do
    req_body = %{deletion_allowed: true} |> Jason.encode!()

    headers = [{"Content-Type", "application/json"}]

    case Client.post("/transit/keys/#{key_name}/config", req_body, headers, options) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        :ok

      error_resp ->
        Logger.error(
          "Encountered HTTP error while enabling key deletion for key #{key_name}: #{inspect(error_resp)}"
        )

        :error
    end
  end

  @spec delete_key(String.t(), list()) :: :ok | :error
  def delete_key(key_name, options \\ []) do
    headers = []

    case Client.delete("/transit/keys/#{key_name}", headers, options) do
      {:ok, %HTTPoison.Response{status_code: 204}} ->
        :ok

      error_resp ->
        Logger.error(
          "Encountered HTTP error while deleting key #{key_name}: #{inspect(error_resp)}"
        )

        :error
    end
  end
end
