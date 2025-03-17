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

defmodule Astarte.Common.Generators.Ip do
  @moduledoc """
  This module provides generators for IP addresses.
  Currently only IPv4 is supported.

  The generated IP addresses are valid according to the Erlang :inet module and
  https://en.wikipedia.org/wiki/Reserved_IP_addresses
  """
  use ExUnitProperties

  @doc """
  Generates a random IPv4 address.
  """
  @spec ip(:ipv4) :: StreamData.t({integer, integer, integer, integer})
  def ip(:ipv4), do: ipv4_address()

  @doc false
  @spec ip(:ipv6) ::
          StreamData.t({integer, integer, integer, integer, integer, integer, integer, integer})
  def ip(:ipv6), do: ipv6_address()

  defp ipv4_address do
    one_of([
      integer(1..9),
      integer(11..126),
      integer(128..223)
    ])
    |> bind(&ipv4_second/1)
  end

  defp ipv4_second(a) do
    second(a)
    |> bind(fn b -> ipv4_third(a, b) end)
  end

  defp ipv4_third(a, b) do
    third(a, b)
    |> bind(fn c -> ipv4_forth(a, b, c) end)
  end

  defp ipv4_forth(a, b, c) do
    tuple({
      constant(a),
      constant(b),
      constant(c),
      integer(1..254)
    })
  end

  defp second(100), do: one_of([integer(0..63), integer(128..255)])
  defp second(169), do: one_of([integer(0..253), constant(255)])
  defp second(172), do: one_of([integer(0..15), integer(32..255)])
  defp second(192), do: one_of([integer(0..87), integer(89..167), integer(169..255)])
  defp second(198), do: one_of([integer(0..17), integer(19..255)])
  defp second(_), do: integer(0..255)

  defp third(198, 51), do: one_of([integer(0..99), integer(101..255)])
  defp third(203, 0), do: one_of([integer(0..112), integer(114..255)])
  defp third(_, _), do: integer(0..255)

  defp ipv6_address do
    raise "Not implemented yet"
  end
end
