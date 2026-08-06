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

defmodule Astarte.Secrets.ClientTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  use Mimic

  alias Astarte.Secrets.Client
  alias Astarte.Secrets.Config

  import Astarte.Common.Generators.HTTP

  setup do
    vault_url = url(path: "", query: "", fragment: "") |> Enum.at(0)
    stub(Config, :vault_url!, fn -> vault_url end)

    header_name = string(:alphanumeric, length: 5..10)
    header_content = string(:alphanumeric)
    headers = list_of(tuple({header_name, header_content}), max_length: 10)

    headers = headers |> Enum.at(0)

    path = "/v1/path"
    request_path = vault_url <> path

    %{vault_url: vault_url, headers: headers, path: path, request_path: request_path}
  end

  describe "request/5" do
    test "adds the token header from the opts", context do
      %{headers: headers, path: path, request_path: request_path} = context
      custom_token = "some-token"

      validate_request(fn :post, ^request_path, headers, "", opts ->
        refute opts[:token]
        assert header_token(headers) == custom_token
      end)

      Client.post(path, "", headers, token: custom_token)
    end

    test "uses default token if not overridden", context do
      %{headers: headers, path: path, request_path: request_path} = context

      validate_request(fn :get, ^request_path, headers, "", opts ->
        refute opts[:token]
        assert header_token(headers) == Config.vault_token!()
      end)

      Client.get(path, headers)
    end

    test "adds the namespace header from the opts", context do
      %{headers: headers, path: path, request_path: request_path} = context
      custom_namespace = "/some/namespace"

      validate_request(fn :delete, ^request_path, headers, "", opts ->
        refute opts[:namespace]
        assert header_namespace(headers) == custom_namespace
      end)

      Client.delete(path, headers, namespace: custom_namespace)
    end

    test "does nothing if the namespace wasn't given", context do
      %{headers: headers, path: path, request_path: request_path} = context

      validate_request(fn :post, ^request_path, headers, "", opts ->
        refute opts[:namespace]
        refute header_namespace(headers)
      end)

      Client.post(path, "", headers)
    end
  end

  describe "request!/5" do
    test "adds the token header from the opts", context do
      %{headers: headers, path: path, request_path: request_path} = context
      custom_token = "some-token"

      validate_request(fn :get, ^request_path, headers, "", opts ->
        refute opts[:token]
        assert header_token(headers) == custom_token
      end)

      Client.get!(path, headers, token: custom_token)
    end

    test "uses default token if not overridden", context do
      %{headers: headers, path: path, request_path: request_path} = context

      validate_request(fn :delete, ^request_path, headers, "", opts ->
        refute opts[:token]
        assert header_token(headers) == Config.vault_token!()
      end)

      Client.delete!(path, headers)
    end

    test "adds the namespace header from the opts", context do
      %{headers: headers, path: path, request_path: request_path} = context
      custom_namespace = "/some/namespace"

      validate_request(fn :post, ^request_path, headers, "", opts ->
        refute opts[:namespace]
        assert header_namespace(headers) == custom_namespace
      end)

      Client.post!(path, "", headers, namespace: custom_namespace)
    end

    test "does nothing if the namespace wasn't given", context do
      %{headers: headers, path: path, request_path: request_path} = context

      validate_request(fn :get, ^request_path, headers, "", opts ->
        refute opts[:namespace]
        refute header_namespace(headers)
      end)

      Client.get!(path, headers)
    end
  end

  describe "get/3" do
    test "adds the token header from the opts", context do
      %{headers: headers, path: path, request_path: request_path} = context
      custom_token = "some-token"

      validate_request(fn :get, ^request_path, headers, "", opts ->
        refute opts[:token]
        assert header_token(headers) == custom_token
      end)

      Client.get(path, headers, token: custom_token)
    end

    test "uses default token if not overridden", context do
      %{headers: headers, path: path, request_path: request_path} = context

      validate_request(fn :get, ^request_path, headers, "", opts ->
        refute opts[:token]
        assert header_token(headers) == Config.vault_token!()
      end)

      Client.get(path, headers)
    end

    test "adds the namespace header from the opts", context do
      %{headers: headers, path: path, request_path: request_path} = context
      custom_namespace = "/some/namespace"

      validate_request(fn :get, ^request_path, headers, "", opts ->
        refute opts[:namespace]
        assert header_namespace(headers) == custom_namespace
      end)

      Client.get(path, headers, namespace: custom_namespace)
    end

    test "does nothing if the namespace wasn't given", context do
      %{headers: headers, path: path, request_path: request_path} = context

      validate_request(fn :get, ^request_path, headers, "", opts ->
        refute opts[:namespace]
        refute header_namespace(headers)
      end)

      Client.get(path, headers)
    end
  end

  describe "list/3" do
    setup context do
      %{request_path: request_path} = context
      request_path = request_path <> "?list=true"

      %{request_path: request_path}
    end

    test "adds the token header from the opts", context do
      %{headers: headers, path: path, request_path: request_path} = context
      custom_token = "some-token"

      validate_request(fn :get, ^request_path, headers, "", opts ->
        refute opts[:token]
        assert header_token(headers) == custom_token
      end)

      Client.list(path, headers, token: custom_token)
    end

    test "uses default token if not overridden", context do
      %{headers: headers, path: path, request_path: request_path} = context

      validate_request(fn :get, ^request_path, headers, "", opts ->
        refute opts[:token]
        assert header_token(headers) == Config.vault_token!()
      end)

      Client.list(path, headers)
    end

    test "adds the namespace header from the opts", context do
      %{headers: headers, path: path, request_path: request_path} = context
      custom_namespace = "/some/namespace"

      validate_request(fn :get, ^request_path, headers, "", opts ->
        refute opts[:namespace]
        assert header_namespace(headers) == custom_namespace
      end)

      Client.list(path, headers, namespace: custom_namespace)
    end

    test "does nothing if the namespace wasn't given", context do
      %{headers: headers, path: path, request_path: request_path} = context

      validate_request(fn :get, ^request_path, headers, "", opts ->
        refute opts[:namespace]
        refute header_namespace(headers)
      end)

      Client.list(path, headers)
    end
  end

  describe "list!/3" do
    setup context do
      %{request_path: request_path} = context
      request_path = request_path <> "?list=true"

      %{request_path: request_path}
    end

    test "adds the token header from the opts", context do
      %{headers: headers, path: path, request_path: request_path} = context
      custom_token = "some-token"

      validate_request(fn :get, ^request_path, headers, "", opts ->
        refute opts[:token]
        assert header_token(headers) == custom_token
      end)

      Client.list!(path, headers, token: custom_token)
    end

    test "uses default token if not overridden", context do
      %{headers: headers, path: path, request_path: request_path} = context

      validate_request(fn :get, ^request_path, headers, "", opts ->
        refute opts[:token]
        assert header_token(headers) == Config.vault_token!()
      end)

      Client.list!(path, headers)
    end

    test "adds the namespace header from the opts", context do
      %{headers: headers, path: path, request_path: request_path} = context
      custom_namespace = "/some/namespace"

      validate_request(fn :get, ^request_path, headers, "", opts ->
        refute opts[:namespace]
        assert header_namespace(headers) == custom_namespace
      end)

      Client.list!(path, headers, namespace: custom_namespace)
    end

    test "does nothing if the namespace wasn't given", context do
      %{headers: headers, path: path, request_path: request_path} = context

      validate_request(fn :get, ^request_path, headers, "", opts ->
        refute opts[:namespace]
        refute header_namespace(headers)
      end)

      Client.list!(path, headers)
    end
  end

  defp header_token(headers) do
    Enum.find_value(headers, fn {key, value} -> key == "X-Vault-Token" && value end)
  end

  defp header_namespace(headers) do
    Enum.find_value(headers, fn {key, value} -> key == "X-Vault-Namespace" && value end)
  end

  defp validate_request(validation_fun) do
    expect(:hackney, :request, fn method, url, headers, body, opts ->
      validation_fun.(method, url, headers, body, opts)
      {:ok, 200, []}
    end)
  end
end
