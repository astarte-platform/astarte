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

defmodule Astarte.FDO.Core.Rendezvous.RvTO2AddrTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.Rendezvous.RvTO2Addr

  describe "for_realm/5" do
    test "prefixes the realm name to the domain when only the domain is given" do
      addr = RvTO2Addr.for_realm("myrealm", "example.com", nil, 443, :https)

      assert addr.dns == "myrealm.example.com"
      assert addr.ip == nil
      assert addr.port == 443
      assert addr.protocol == :https
    end

    test "uses the IP address as-is, without a realm prefix, when only the IP is given" do
      addr = RvTO2Addr.for_realm("myrealm", nil, "192.168.1.10", 8080, :http)

      assert addr.dns == nil
      assert addr.ip == <<192, 168, 1, 10>>
    end

    test "encodes IPv6 addresses to their 16-byte representation" do
      addr = RvTO2Addr.for_realm("myrealm", nil, "::1", 8080, :http)

      assert addr.ip == <<0::16, 0::16, 0::16, 0::16, 0::16, 0::16, 0::16, 1::16>>
    end

    test "includes both addresses when both domain and IP are configured" do
      addr = RvTO2Addr.for_realm("myrealm", "example.com", "192.168.1.10", 443, :https)

      assert addr.dns == "myrealm.example.com"
      assert addr.ip == <<192, 168, 1, 10>>
    end

    test "treats blank strings as absent, same as nil" do
      addr = RvTO2Addr.for_realm("myrealm", "", "192.168.1.10", 443, :https)

      assert addr.dns == nil
      assert addr.ip == <<192, 168, 1, 10>>

      assert_raise FunctionClauseError, fn ->
        RvTO2Addr.for_realm("myrealm", "", "", 443, :https)
      end
    end

    test "raises when neither domain nor IP is given" do
      assert_raise FunctionClauseError, fn ->
        RvTO2Addr.for_realm("myrealm", nil, nil, 443, :https)
      end
    end

    test "raises ArgumentError when the IP address is malformed" do
      assert_raise ArgumentError, ~r/invalid IP address/, fn ->
        RvTO2Addr.for_realm("myrealm", nil, "not an ip", 443, :https)
      end
    end
  end

  describe "encode/1" do
    test "returns the list in the expected format" do
      addr = RvTO2Addr.for_realm("myrealm", "example.com", "192.168.1.10", 443, :https)

      assert RvTO2Addr.encode(addr) == [addr.ip, addr.dns, 443, RvTO2Addr.encode_protocol(:https)]
    end
  end

  describe "encode_list/1" do
    test "encodes a list of entries" do
      addr = RvTO2Addr.for_realm("myrealm", "example.com", nil, 443, :https)

      assert RvTO2Addr.encode_list([addr]) == [RvTO2Addr.encode(addr)]
    end
  end

  describe "encode_protocol/1" do
    test "maps every known protocol to its numeric id" do
      for {protocol, id} <- [tcp: 1, tls: 2, http: 3, coap: 4, https: 5, coaps: 6] do
        assert RvTO2Addr.encode_protocol(protocol) == id
      end
    end
  end
end
