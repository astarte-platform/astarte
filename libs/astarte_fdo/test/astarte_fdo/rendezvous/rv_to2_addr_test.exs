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

defmodule Astarte.FDO.Rendezvous.RvTO2AddrTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Config
  alias Astarte.FDO.Core.Rendezvous.RvTO2Addr

  setup_all do
    realm = "realm#{System.unique_integer([:positive])}"

    addr =
      RvTO2Addr.for_realm(
        realm,
        Config.base_url_domain!(),
        Config.base_url_ip!(),
        Config.base_url_port!(),
        Config.base_url_protocol!()
      )

    %{rv_to2_addr: addr, realm_name: realm}
  end

  describe "for_realm/5" do
    test "returns the default configuration for the realm", %{realm_name: realm_name} do
      domain = Config.base_url_domain!()
      port = Config.base_url_port!()
      protocol = Config.base_url_protocol!()

      realm_config = RvTO2Addr.for_realm(realm_name, domain, nil, port, protocol)

      assert realm_config.port == port
      assert realm_config.protocol == protocol
      assert realm_config.dns == "#{realm_name}.#{domain}"
      assert realm_config.ip == nil
    end

    test "prefixes the realm name only to the domain, not to the IP address", %{
      realm_name: realm_name
    } do
      port = Config.base_url_port!()
      protocol = Config.base_url_protocol!()

      realm_config = RvTO2Addr.for_realm(realm_name, nil, "192.168.1.10", port, protocol)

      assert realm_config.dns == nil
      assert realm_config.ip == <<192, 168, 1, 10>>
    end

    test "includes both addresses when both domain and IP are configured", %{
      realm_name: realm_name
    } do
      port = Config.base_url_port!()
      protocol = Config.base_url_protocol!()

      realm_config =
        RvTO2Addr.for_realm(realm_name, "example.com", "192.168.1.10", port, protocol)

      assert realm_config.dns == "#{realm_name}.example.com"
      assert realm_config.ip == <<192, 168, 1, 10>>
    end

    test "encodes IPv6 addresses to their 16-byte representation", %{realm_name: realm_name} do
      port = Config.base_url_port!()
      protocol = Config.base_url_protocol!()

      realm_config = RvTO2Addr.for_realm(realm_name, nil, "::1", port, protocol)

      assert realm_config.ip == <<0::16, 0::16, 0::16, 0::16, 0::16, 0::16, 0::16, 1::16>>
    end

    test "raises when neither domain nor IP is given", %{realm_name: realm_name} do
      port = Config.base_url_port!()
      protocol = Config.base_url_protocol!()

      assert_raise FunctionClauseError, fn ->
        RvTO2Addr.for_realm(realm_name, nil, nil, port, protocol)
      end
    end

    test "treats blank strings as absent, same as nil", %{realm_name: realm_name} do
      port = Config.base_url_port!()
      protocol = Config.base_url_protocol!()

      assert_raise FunctionClauseError, fn ->
        RvTO2Addr.for_realm(realm_name, "", "", port, protocol)
      end

      realm_config = RvTO2Addr.for_realm(realm_name, "", "192.168.1.10", port, protocol)
      assert realm_config.dns == nil
      assert realm_config.ip == <<192, 168, 1, 10>>
    end

    test "raises ArgumentError when the IP address is malformed", %{realm_name: realm_name} do
      port = Config.base_url_port!()
      protocol = Config.base_url_protocol!()

      assert_raise ArgumentError, ~r/invalid IP address/, fn ->
        RvTO2Addr.for_realm(realm_name, nil, "not an ip", port, protocol)
      end
    end
  end

  describe "encode/1" do
    test "returns the list in the expected format", %{rv_to2_addr: addr} do
      assert [ip, dns, port, protocol] = RvTO2Addr.encode(addr)
      assert ip == addr.ip
      assert dns == addr.dns
      assert port == addr.port
      assert protocol == RvTO2Addr.encode_protocol(addr.protocol)
    end
  end

  describe "encode_list/1" do
    test "encodes a list of entries", %{rv_to2_addr: addr} do
      expected = [RvTO2Addr.encode(addr)]
      assert RvTO2Addr.encode_list([addr]) == expected
    end
  end
end
