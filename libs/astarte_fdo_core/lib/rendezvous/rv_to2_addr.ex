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

defmodule Astarte.FDO.Core.Rendezvous.RvTO2Addr do
  @moduledoc """
  Module for handling the RvTO2Addr structure in the FDO Rendezvous protocol, including
  generating the address for a given realm based on the configuration and encoding it
  in the format expected by the protocol.
  """

  use TypedStruct

  alias Astarte.FDO.Core.Rendezvous.RvTO2Addr

  @protocol_to_id %{
    tcp: 1,
    tls: 2,
    http: 3,
    coap: 4,
    https: 5,
    coaps: 6
  }

  @type protocol :: :tcp | :tls | :http | :coap | :https | :coaps

  typedstruct do
    field :ip, binary() | nil
    field :dns, String.t() | nil
    field :port, non_neg_integer()
    field :protocol, protocol()
  end

  # A blank string is treated the same as nil: neither counts as "configured".
  defguardp is_present(value) when is_binary(value) and value != ""

  @doc """
  Builds the RvTO2Addr entry for `realm_name`, given the configured base
  `domain` and/or `ip` (at least one of the two is required).
  """
  def for_realm(realm_name, domain, ip, port, protocol)
      when is_present(domain) or is_present(ip) do
    dns = if is_present(domain), do: "#{realm_name}.#{domain}"
    ip_bytes = if is_present(ip), do: encode_ip(ip)

    %RvTO2Addr{ip: ip_bytes, dns: dns, port: port, protocol: protocol}
  end

  defp encode_ip(ip_string) do
    case ip_string |> String.to_charlist() |> :inet.parse_address() do
      {:ok, address} ->
        ip_tuple_to_bytes(address)

      {:error, reason} ->
        raise ArgumentError, "invalid IP address #{inspect(ip_string)}: #{inspect(reason)}"
    end
  end

  defp ip_tuple_to_bytes({a, b, c, d}), do: <<a, b, c, d>>

  defp ip_tuple_to_bytes({a, b, c, d, e, f, g, h}) do
    <<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>>
  end

  def encode(rv_to2_addr) do
    %RvTO2Addr{ip: ip, dns: dns, port: port, protocol: protocol} = rv_to2_addr
    protocol_id = encode_protocol(protocol)

    [ip, dns, port, protocol_id]
  end

  def encode_list(rv_to2_addr_list) do
    rv_to2_addr_list
    |> Enum.map(&encode/1)
  end

  @doc false
  def encode_protocol(protocol) do
    Map.fetch!(@protocol_to_id, protocol)
  end
end
