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

defmodule Astarte.Secrets.Client do
  @moduledoc """
  Client for OpenBao
  """

  use Astarte.Config.HTTPClient, config: Astarte.Secrets.Config, service: :vault

  alias Config.Reader

  alias Astarte.Secrets.Config
  alias HTTPoison.AsyncResponse
  alias HTTPoison.Error
  alias HTTPoison.Response

  @impl true
  def request(method, url, body \\ "", headers \\ [], options \\ []) do
    {headers, options} = populate_vault_headers(headers, options)
    super(method, url, body, headers, options)
  end

  @doc """
  Issues a LIST request to the given url.

  Returns `{:ok, response}` if the request is successful, `{:error, reason}`
  otherwise.

  See `request/5` for more detailed information.
  """
  @spec list(binary, headers, Keyword.t()) ::
          {:ok, Response.t() | AsyncResponse.t()} | {:error, Error.t()}
  def list(url, headers \\ [], options \\ []) do
    list_opts = [params: [list: "true"]]
    options = Reader.merge(options, list_opts)
    get(url, headers, options)
  end

  @doc """
  Issues a LIST request to the given url, raising an exception in case of
  failure.

  If the request does not fail, the response is returned.

  See `request!/5` for more detailed information.
  """
  @spec list!(binary, headers, Keyword.t()) :: Response.t() | AsyncResponse.t()
  def list!(url, headers \\ [], options \\ []) do
    list_opts = [params: [list: "true"]]
    options = Reader.merge(options, list_opts)
    get!(url, headers, options)
  end

  # add here custom headers for Vault API calls
  defp populate_vault_headers(headers, opts) do
    {token, opts} = Keyword.pop(opts, :token, Config.vault_token!())
    {namespace, opts} = Keyword.pop(opts, :namespace)
    headers = headers |> add_token_to_header(token) |> add_namespace_to_header(namespace)
    {headers, opts}
  end

  defp add_token_to_header(headers, token) do
    [{"X-Vault-Token", token} | headers]
  end

  defp add_namespace_to_header(headers, namespace) do
    case namespace do
      nil -> headers
      namespace -> [{"X-Vault-Namespace", namespace} | headers]
    end
  end
end
