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
  alias Astarte.FDO.Config.BaseURLIp
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

  describe "BaseURLIp.cast/1" do
    test "casts and normalizes valid IPv4 and IPv6 addresses" do
      assert {:ok, "192.168.1.10"} == BaseURLIp.cast("192.168.1.10")
      assert {:ok, "::1"} == BaseURLIp.cast("::1")
      assert {:ok, "::1"} == BaseURLIp.cast("0:0:0:0:0:0:0:1")
    end

    test "returns error for invalid IP addresses" do
      assert :error == BaseURLIp.cast("not an ip")
      assert :error == BaseURLIp.cast("999.999.999.999")
    end

    test "returns error for unrecognised value" do
      assert :error == BaseURLIp.cast(1234)
    end
  end

  describe "base_url_host!/0" do
    test "prefers the domain over the IP address when both are configured" do
      stub(Config, :base_url_domain!, fn -> "astarte.example.com" end)
      stub(Config, :base_url_ip!, fn -> "192.168.1.10" end)

      assert Config.base_url_host!() == "astarte.example.com"
    end

    test "falls back to the IP address when the domain is not configured" do
      stub(Config, :base_url_domain!, fn -> nil end)
      stub(Config, :base_url_ip!, fn -> "192.168.1.10" end)

      assert Config.base_url_host!() == "192.168.1.10"
    end

    test "treats a blank domain as unconfigured, same as nil" do
      stub(Config, :base_url_domain!, fn -> "" end)
      stub(Config, :base_url_ip!, fn -> "192.168.1.10" end)

      assert Config.base_url_host!() == "192.168.1.10"
    end

    test "returns nil when neither is configured (including blank strings)" do
      stub(Config, :base_url_domain!, fn -> "" end)
      stub(Config, :base_url_ip!, fn -> nil end)

      assert Config.base_url_host!() == nil
    end
  end

  describe "base_url!/0" do
    test "builds the URL from protocol, domain and port" do
      stub(Config, :base_url_protocol!, fn -> :https end)
      stub(Config, :base_url_domain!, fn -> "astarte.example.com" end)
      stub(Config, :base_url_ip!, fn -> nil end)
      stub(Config, :base_url_port!, fn -> 443 end)

      assert Config.base_url!() == "https://astarte.example.com:443"
    end

    test "falls back to the IP address when no domain is configured" do
      stub(Config, :base_url_protocol!, fn -> :http end)
      stub(Config, :base_url_domain!, fn -> nil end)
      stub(Config, :base_url_ip!, fn -> "192.168.1.10" end)
      stub(Config, :base_url_port!, fn -> 80 end)

      assert Config.base_url!() == "http://192.168.1.10:80"
    end
  end

  describe "init!/0" do
    test "raises when neither the domain nor the IP address is configured" do
      stub(Config, :base_url_domain!, fn -> nil end)
      stub(Config, :base_url_ip!, fn -> nil end)

      assert_raise RuntimeError,
                   "At least one of ASTARTE_BASE_URL_DOMAIN or ASTARTE_BASE_URL_IP must be configured",
                   fn -> Config.init!() end
    end

    test "raises when the domain is a blank string and no IP is configured" do
      stub(Config, :base_url_domain!, fn -> "" end)
      stub(Config, :base_url_ip!, fn -> nil end)

      assert_raise RuntimeError,
                   "At least one of ASTARTE_BASE_URL_DOMAIN or ASTARTE_BASE_URL_IP must be configured",
                   fn -> Config.init!() end
    end

    test "does not raise when the domain is configured" do
      stub(Config, :base_url_domain!, fn -> "astarte.example.com" end)
      stub(Config, :base_url_ip!, fn -> nil end)

      assert Config.init!() == :ok
    end

    test "does not raise when the IP address is configured" do
      stub(Config, :base_url_domain!, fn -> nil end)
      stub(Config, :base_url_ip!, fn -> "192.168.1.10" end)

      assert Config.init!() == :ok
    end
  end
end
