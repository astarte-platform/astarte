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
    test "prefixes the realm name to a domain host" do
      addr = RvTO2Addr.for_realm("myrealm", :domain, "example.com", 443, :https)

      assert addr.dns == "myrealm.example.com"
      assert addr.ip == nil
      assert addr.port == 443
      assert addr.protocol == :https
    end

    test "encodes an IPv4 host, without a realm prefix" do
      addr = RvTO2Addr.for_realm("myrealm", :ip, {192, 168, 1, 10}, 8080, :http)

      assert addr.dns == nil
      assert addr.ip == <<192, 168, 1, 10>>
    end

    test "encodes an IPv6 host to its 16-byte representation" do
      addr = RvTO2Addr.for_realm("myrealm", :ip, {0, 0, 0, 0, 0, 0, 0, 1}, 8080, :http)

      assert addr.dns == nil
      assert addr.ip == <<0::16, 0::16, 0::16, 0::16, 0::16, 0::16, 0::16, 1::16>>
    end

    test "raises for an unknown host type" do
      assert_raise FunctionClauseError, fn ->
        RvTO2Addr.for_realm("myrealm", :mystery, "example.com", 443, :https)
      end
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
