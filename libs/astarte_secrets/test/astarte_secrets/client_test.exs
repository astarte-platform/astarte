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
  use Mimic

  alias Astarte.Secrets.Client
  alias Astarte.Secrets.Config

  import Astarte.Common.Generators.HTTP

  setup do
    bao_url = url(path: "", query: "", fragment: "") |> Enum.at(0)
    stub(Config, :bao_url!, fn -> bao_url end)

    %{bao_url: bao_url}
  end

  test "always performs requests on the open bao base url", %{bao_url: bao_url} do
    path = "/example"
    expected_url = bao_url <> "/v1" <> path

    validate_request(fn _method, url, _headers, _body, _opts ->
      assert url == expected_url
    end)

    assert {:ok, _} = Client.get(path)
  end

  describe "respects ssl options" do
    setup :enable_ssl

    test "with default sni" do
      path = "/example"

      validate_request(fn _method, url, _headers, _body, opts ->
        uri = URI.parse(url)
        ssl_opts = Keyword.fetch!(opts, :ssl_options)

        assert ssl_opts[:cacertfile]
        assert ssl_opts[:verify] == :verify_peer
        assert ssl_opts[:server_name_indication] == to_charlist(uri.host)
      end)

      Client.get(path)
    end

    test "with custom sni" do
      path = "/example"
      custom_sni = "custom-sni"

      stub(Config, :bao_ssl_custom_sni!, fn -> custom_sni end)

      validate_request(fn _method, _url, _headers, _body, opts ->
        ssl_opts = Keyword.fetch!(opts, :ssl_options)

        assert ssl_opts[:cacertfile]
        assert ssl_opts[:verify] == :verify_peer
        assert ssl_opts[:server_name_indication] == to_charlist(custom_sni)
      end)

      Client.get(path)
    end

    test "without sni" do
      path = "/example"

      stub(Config, :bao_ssl_disable_sni!, fn -> true end)

      validate_request(fn _method, _url, _headers, _body, opts ->
        ssl_opts = Keyword.fetch!(opts, :ssl_options)

        assert ssl_opts[:cacertfile]
        assert ssl_opts[:verify] == :verify_peer
        assert ssl_opts[:server_name_indication] == :disable
      end)

      Client.get(path)
    end
  end

  defp enable_ssl(_context) do
    stub(Config, :bao_ssl_enabled!, fn -> true end)
    :ok
  end

  defp validate_request(validation_fun) do
    expect(:hackney, :request, fn method, url, headers, body, opts ->
      validation_fun.(method, url, headers, body, opts)
      {:ok, 200, []}
    end)
  end
end
