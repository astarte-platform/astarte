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

defmodule Astarte.Pairing.FDO.Rendezvous.RvTO2Addr do
  use TypedStruct

  alias Astarte.Pairing.Config
  alias Astarte.Pairing.FDO.Rendezvous.RvTO2Addr
  alias Astarte.PairingWeb.Endpoint

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

  def for_realm(realm_name) do
    base_domain = Config.base_domain!()
    dns = "#{realm_name}.#{base_domain}"
    {protocol, port} = default_endpoint_config()

    %RvTO2Addr{dns: dns, port: port, protocol: protocol}
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

  defp default_endpoint_config do
    cond do
      http = Endpoint.config(:http) ->
        port = Keyword.fetch!(http, :port)
        {:http, port}

      https = Endpoint.config(:https) ->
        port = Keyword.fetch!(https, :port)
        {:https, port}
    end
  end
end
