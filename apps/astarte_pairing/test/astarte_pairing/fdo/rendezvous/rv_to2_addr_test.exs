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

defmodule Astarte.Pairing.FDO.Rendezvous.RvTO2AddrTest do
  use ExUnit.Case, async: true

  alias Astarte.Pairing.FDO.Rendezvous.RvTO2Addr
  alias Astarte.Pairing.Config

  setup_all do
    realm = "realm#{System.unique_integer([:positive])}"
    addr = RvTO2Addr.for_realm(realm)

    %{rv_to2_addr: addr, realm_name: realm}
  end

  describe "for_realm/1" do
    test "returns the default configuration for the realm", %{realm_name: realm_name} do
      realm_config = RvTO2Addr.for_realm(realm_name)

      expected_dns = "#{realm_name}.#{Config.base_domain!()}"

      assert realm_config.port == 4003
      assert realm_config.protocol == :http
      assert realm_config.dns == expected_dns
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
