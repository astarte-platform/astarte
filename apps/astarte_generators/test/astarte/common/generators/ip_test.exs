#
# This file is part of Astarte.
#
# Copyright 2025 - 2026 SECO Mind Srl
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

defmodule Astarte.Common.Generators.IpTest do
  @moduledoc """
  Tests for the IP generator.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  import StreamData, only: [constant: 1]

  import Astarte.Common.Generators.Ip

  @moduletag :common
  @moduletag :ip

  describe "ip generator" do
    @doc """
    Property test for the IP generator.
    Valid IPs are not present in the reserved list (see: https://en.wikipedia.org/wiki/Reserved_IP_addresses)
    """
    property "valid IPv4 addresses (probabilistic coverage)" do
      check all {a, b, c, d} = ip <- ip(:ipv4) do
        assert valid_ipv4?(ip), "Generated an invalid IPv4 address: #{a}.#{b}.#{c}.#{d}"
      end
    end

    @doc false
    property "hits all specific pattern matching branches for IPv4" do
      check all ip100 <- ip(:ipv4, first: constant(100)),
                ip169 <- ip(:ipv4, first: constant(169)),
                ip172 <- ip(:ipv4, first: constant(172)),
                ip192 <- ip(:ipv4, first: constant(192)),
                ip198_sec <- ip(:ipv4, first: constant(198)),
                ip198_third <- ip(:ipv4, first: constant(198), second: constant(51)),
                ip203_third <- ip(:ipv4, first: constant(203), second: constant(0)) do
        assert valid_ipv4?(ip100)
        assert valid_ipv4?(ip169)
        assert valid_ipv4?(ip172)
        assert valid_ipv4?(ip192)
        assert valid_ipv4?(ip198_sec)
        assert valid_ipv4?(ip198_third)
        assert valid_ipv4?(ip203_third)
      end
    end

    test "IPv6 generator raises not implemented exception" do
      assert_raise RuntimeError, "Not implemented yet", fn ->
        ip(:ipv6)
      end
    end
  end

  # Helpers
  defp valid_ipv4?({a, b, c, d} = ip)
       when a in 0..255 and b in 0..255 and c in 0..255 and d in 0..255 do
    not reserved_ip?(ip)
  end

  defp valid_ipv4?(_), do: false

  defp reserved_ip?({10, _, _, _}), do: true
  defp reserved_ip?({127, _, _, _}), do: true
  defp reserved_ip?({169, 254, _, _}), do: true
  defp reserved_ip?({172, second, _, _}) when second in 16..31, do: true
  defp reserved_ip?({192, 168, _, _}), do: true
  defp reserved_ip?({a, _, _, _}) when a in 224..255, do: true
  defp reserved_ip?(_), do: false
end
