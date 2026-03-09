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

defmodule Astarte.Pairing.FDO.OpenBao.Core do
  @moduledoc """
  Implementation of function to interface with OpenBao.
  """

  alias Astarte.DataAccess.Config, as: DataAccessConfig
  alias Astarte.Pairing.FDO.OpenBao.Client
  alias HTTPoison.Response

  require Logger

  @type key_algorithm :: :ec256 | :ec384 | :rsa2048 | :rsa3072

  @spec key_type_to_string(key_algorithm()) :: {:ok, String.t()} | :error
  def key_type_to_string(key_type) do
    case key_type do
      :ec256 -> {:ok, "ecdsa-p256"}
      :ec384 -> {:ok, "ecdsa-p384"}
      :rsa2048 -> {:ok, "rsa-2048"}
      :rsa3072 -> {:ok, "rsa-3072"}
      _ -> :error
    end
  end

  @spec create_keypair(String.t(), String.t(), boolean(), String.t()) ::
          :error | {:error, Jason.DecodeError.t()} | {:ok, any()}
  def create_keypair(key_name, key_type, allow_key_export_and_backup, namespace) do
    req_body =
      %{
        type: key_type,
        exportable: allow_key_export_and_backup,
        allow_plaintext_backup: allow_key_export_and_backup
      }
      |> Jason.encode!()

    headers = [{"Content-Type", "application/json"}]

    options = [{:namespace, namespace}]

    case Client.post("/transit/keys/#{key_name}", req_body, headers, options) do
      {:ok, %HTTPoison.Response{status_code: 200, body: resp_body}} ->
        parse_json_data(resp_body)

      error_resp ->
        Logger.error(
          "Encountered HTTP error while creating key #{key_name}: #{inspect(error_resp)}"
        )

        :error
    end
  end

  @doc """
  Returns the namespace name for the given params, represented as a list of tokens
  """
  def namespace_tokens(realm_name, user_id, key_algorithm) do
    ["fdo_owner_keys", instance_tokens(), realm_name, user_tokens(user_id), key_algorithm]
    |> List.flatten()
  end

  defp instance_tokens do
    case DataAccessConfig.astarte_instance_id!() do
      "" ->
        "default_instance"

      instance_id ->
        ["instance", instance_id]
    end
  end

  defp user_tokens(nil), do: "default_user"
  defp user_tokens(user_id), do: ["user_id", user_id]

  def create_nested_namespace(namespace_tokens) do
    Enum.reduce_while(namespace_tokens, {:ok, ""}, fn new_namespace, {:ok, base_namespace} ->
      headers = []
      options = [namespace: base_namespace]

      case Client.post("/sys/namespaces/#{new_namespace}", "", headers, options) do
        {:ok, %HTTPoison.Response{status_code: 200}} ->
          new_base_namespace = Path.join(base_namespace, new_namespace)
          {:cont, {:ok, new_base_namespace}}

        error ->
          "Error creating new namespace #{new_namespace} on #{base_namespace}: #{inspect(error)}"
          |> Logger.error()

          {:halt, {:error, :namespace_creation_error}}
      end
    end)
  end

  def mount_transit_engine(namespace) do
    req_body = %{type: "transit"} |> Jason.encode!()
    headers = [{"Content-Type", "application/json"}]
    options = [{:namespace, namespace}]

    case Client.post("/sys/mounts/transit", req_body, headers, options) do
      {:ok, %HTTPoison.Response{status_code: 204}} ->
        :ok

      error_resp ->
        Logger.error(
          "Encountered HTTP error while mounting transit engine in namespace #{namespace}: #{inspect(error_resp)}"
        )

        :error
    end
  end

  defp parse_data_key(json_str, key) do
    with {:ok, data} <- parse_json_data(json_str) do
      fetch_data_key(data, key)
    end
  end

  defp parse_json_data(json_str) do
    with {:ok, map} when is_map(map) <- Jason.decode(json_str),
         {:ok, data} <- Map.fetch(map, "data") do
      {:ok, data}
    else
      _ -> {:error, {:invalid_response_body, json_str}}
    end
  end

  defp fetch_data_key(data, key) do
    with :error <- Map.fetch(data, key) do
      {:error, {:unexpected_body_format, data}}
    end
  end

  def list_namespaces(base_namespace \\ "", acc \\ MapSet.new()) do
    with {:ok, children} <- list_relative_namespaces(base_namespace) do
      child_namespaces = children |> Enum.map(&(base_namespace <> &1))
      acc = child_namespaces |> MapSet.new() |> MapSet.union(acc)

      Enum.reduce_while(children, {:ok, acc}, &do_list_namespaces(base_namespace, &1, &2))
    end
  end

  defp list_relative_namespaces(base_namespace) do
    headers = [{"X-Vault-Namespace", base_namespace}]

    case Client.list("/sys/namespaces", headers) do
      {:ok, %Response{status_code: 200, body: body}} ->
        case parse_data_key(body, "keys") do
          {:ok, _keys} = ok ->
            ok

          error ->
            Logger.warning("Error while listing namespaces: #{inspect(error)}")
            error
        end

      {:ok, %Response{status_code: 404}} ->
        # Responds with 404 when there is no relative namespace
        {:ok, []}

      error ->
        Logger.warning("Error while listing namespaces: #{inspect(error)}")
        error
    end
  end

  defp do_list_namespaces(base_namespace, child, {:ok, acc}) do
    child_namespace = base_namespace <> child

    case list_namespaces(child_namespace, acc) do
      {:ok, child_branch} ->
        acc = child_branch |> MapSet.new() |> MapSet.union(acc)
        {:cont, {:ok, acc}}

      error ->
        {:halt, error}
    end
  end
end
