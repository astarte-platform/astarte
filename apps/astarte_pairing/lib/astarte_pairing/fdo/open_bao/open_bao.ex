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
  alias Astarte.Pairing.FDO.OpenBao.Client
  alias Astarte.Pairing.FDO.OpenBao.Core
  alias Astarte.Pairing.FDO.OpenBao.Key
  alias COSE.Keys.ECC
  alias COSE.Keys.RSA

  require Logger

  @spec get_key(String.t()) :: {:ok, map()} | :error
  def get_key(key_name, opts \\ []) do
    namespace = Keyword.fetch!(opts, :namespace)

    with {:ok, resp} <- Core.get_key(key_name, namespace) do
      Key.parse(key_name, namespace, resp)
    end
  end

  @spec list_keys_names() :: {:ok, [String.t()]} | :error
  def list_keys_names(opts \\ []) do
    namespace = Keyword.fetch!(opts, :namespace)

    Core.list_keys(namespace)
  end

  def create_namespace(realm_name, user_id \\ nil, key_algorithm) do
    with {:ok, algorithm} <- Core.key_type_to_string(key_algorithm),
         namespace_tokens = Core.namespace_tokens(realm_name, user_id, algorithm),
         {:ok, namespace} <- Core.create_nested_namespace(namespace_tokens),
         :ok <- Core.mount_transit_engine(namespace) do
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

  @spec sign(String.t(), binary(), Core.key_algorithm(), Core.digest_type(), keyword()) ::
          {:ok, binary()} | :error
  def sign(key_name, payload, key_alg, digest_type, opts) do
    opts = Keyword.take(opts, [:namespace, :token])

    with {:ok, digest_type} <- Core.digest_type(digest_type) do
      Core.sign(key_name, payload, key_alg, digest_type, opts)
    end
  end

  @type cose_key :: %ECC{} | %RSA{}

  @spec import_key(String.t(), Core.key_algorithm(), cose_key(), list()) :: :ok | :error
  def import_key(key_name, key_type, key, opts \\ []) do
    namespace = Keyword.fetch!(opts, :namespace)
    client_opts = [namespace: namespace] ++ Keyword.take(opts, [:token])

    with {:ok, key_type_string} <- Core.key_type_to_string(key_type),
         {:ok, wrapping_key_pem} <- Core.get_wrapping_key(client_opts),
         {:ok, ciphertext} <-
           Core.prepare_import_ciphertext(Core.encode_key_to_pkcs8(key), wrapping_key_pem) do
      Core.import_key(key_name, key_type_string, ciphertext, opts)
    end
  end
end
