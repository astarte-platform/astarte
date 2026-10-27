#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.FDO.ConfigTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Astarte.FDO.Config
  alias Astarte.FDO.Config.BaseURLHost
  alias Astarte.FDO.Config.BaseURLProtocol

  describe "BaseURLProtocol.cast/1" do
    test "casts valid string protocols" do
      for proto <- ["tcp", "tls", "http", "coap", "https", "coaps"] do
        assert {:ok, String.to_atom(proto)} == BaseURLProtocol.cast(proto)
      end
    end

    test "accepts already-atom protocols" do
      for proto <- [:tcp, :tls, :http, :coap, :https, :coaps] do
        assert {:ok, proto} == BaseURLProtocol.cast(proto)
      end
    end

    test "returns error for unknown string" do
      assert :error == BaseURLProtocol.cast("ftp")
    end

    test "returns error for unrecognised value" do
      assert :error == BaseURLProtocol.cast(1234)
    end
  end

  describe "base_url!/0" do
    test "builds the URL from protocol, a domain host and port" do
      domain_host = %BaseURLHost{type: :domain, value: "astarte.example.com"}
      stub(Config, :base_url_protocol!, fn -> :https end)
      stub(Config, :base_url_host!, fn -> domain_host end)
      stub(Config, :base_url_port!, fn -> 443 end)

      assert Config.base_url!() == "https://astarte.example.com:443"
    end

    test "builds the URL from an IP host" do
      ip_host = %BaseURLHost{type: :ip, value: {192, 168, 1, 10}}
      stub(Config, :base_url_protocol!, fn -> :http end)
      stub(Config, :base_url_host!, fn -> ip_host end)
      stub(Config, :base_url_port!, fn -> 4003 end)

      assert Config.base_url!() == "http://192.168.1.10:4003"
    end
  end
end
