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

defmodule Astarte.Common.Generators.IpTest do
  @moduledoc """
  Tests for the IP generator.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Common.Generators.Ip, as: IpGenerator

  @moduletag :common
  @moduletag :ip

  @doc """
  Property test for the IP generator.
  Valid IPs are not present in the reserved list (see: https://en.wikipedia.org/wiki/Reserved_IP_addresses)
  """
  describe "ip generator" do
    property "valid IPv4 addresses" do
      check all({a, b, c, d} = ip <- IpGenerator.ip(:ipv4)) do
        assert valid_ipv4?(ip), "Generated an invalid IPv4 address: #{a}.#{b}.#{c}.#{d}"
      end
    end
  end

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
