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

defmodule Astarte.Core.Generators.Device do
  @moduledoc """
  Astarte Device generator.
  """
  use ExUnitProperties

  alias Astarte.Core.Interface
  alias Astarte.Core.Device
  alias Astarte.Common.Generators.Ip, as: IpGenerator
  alias Astarte.Common.Generators.Timestamp, as: TimestampGenerator
  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator

  @doc """
  Generates a random Device based on the given Interfaces.

  See https://github.com/astarte-platform/astarte_core/blob/master/lib/astarte_core/device.ex
  """
  # @spec device(StreamData.t(%Interface{})) :: StreamData.t(term())
  def temp() do
    gen all(
          interface <- InterfaceGenerator.interface()
          # interfaces <- list_of(interface, max_length: 10)
          # {interfaces_msgs, interfaces_bytes} <-
          #   interfaces
          #   |> map(fn i -> i.name end)
          #   |> interface_maps()
        ) do
      interface
      # {interfaces_msgs, interfaces_bytes}
    end
  end

  def device(interfaces) do
    gen all(
          id <- id(),
          last_seen_ip <- IpGenerator.ip(:ipv4),
          last_credentials_request_ip <- IpGenerator.ip(:ipv4),
          inhibit_credentials_request <- boolean(),
          {
            first_registration,
            first_credentials_request,
            last_connection,
            last_disconnection
          } <- timestamps(),
          {interfaces_msgs, interfaces_bytes} <-
            interfaces
            |> map(fn i -> i.name end)
            |> interface_maps(),
          aliases <- aliases(),
          attributes <- attributes()
        ) do
      %{
        id: id,
        device_id: id,
        encoded_id: Device.encode_device_id(id),
        connected: DateTime.after?(last_connection, last_disconnection),
        first_registration: first_registration,
        first_credentials_request: first_credentials_request,
        last_connection: last_connection,
        last_disconnection: last_disconnection,
        last_seen_ip: last_seen_ip,
        inhibit_credentials_request: inhibit_credentials_request,
        last_credentials_request_ip: last_credentials_request_ip,
        interfaces_msgs: interfaces_msgs,
        interfaces_bytes: interfaces_bytes,
        aliases: aliases,
        attributes: attributes,
        total_received_msgs: Enum.reduce(interfaces_msgs, 0, fn {_, msgs}, acc -> acc + msgs end),
        total_received_bytes:
          Enum.reduce(interfaces_bytes, 0, fn {_, bytes}, acc -> acc + bytes end)
      }
    end
  end

  @spec id() :: StreamData.t(binary())
  def id() do
    gen all(seq <- binary(length: 16)) do
      <<u0::48, _::4, u1::12, _::2, u2::62>> = seq
      <<u0::48, 4::4, u1::12, 2::2, u2::62>>
    end
  end

  @spec encoded_id() :: StreamData.t(binary())
  def encoded_id() do
    gen all(id <- id()) do
      Base.url_encode64(id, padding: false)
    end
  end

  defp received do
    gen all(
          msgs <- integer(1..10_000),
          bytes <- integer(10..10_000)
        ) do
      {msgs, msgs * bytes}
    end
  end

  defp aliases do
    one_of([
      map_of(string(:alphanumeric, min_length: 1), string(:alphanumeric, min_length: 1)),
      constant(nil)
    ])
  end

  defp attributes do
    one_of([
      map_of(string(:alphanumeric, min_length: 1), string(:alphanumeric, min_length: 1)),
      constant(nil)
    ])
  end

  defp interface_maps(interface_names) do
    one_of([
      member_of(interface_names)
      |> Enum.take(length(interface_names))
      |> Enum.uniq()
      |> Enum.map(fn name -> {name, 0..1 |> Enum.random()} end)
      |> Enum.reduce({%{}, %{}}, fn i, {msgs, bytes} ->
        {m, b} = received() |> Enum.at(0)

        {
          Map.merge(msgs, %{i => m}),
          Map.merge(bytes, %{i => b})
        }
      end)
      |> constant(),
      constant(nil)
    ])
  end

  defp timestamps() do
    time_zone = "Etc/UTC"

    gen all(
          last_disconnection <-
            TimestampGenerator.timestamp(max: DateTime.to_unix(DateTime.now!(time_zone))),
          last_connection <-
            TimestampGenerator.timestamp(max: DateTime.to_unix(DateTime.now!(time_zone))),
          first_credentials_request <-
            TimestampGenerator.timestamp(max: last_connection),
          first_registration <-
            TimestampGenerator.timestamp(max: first_credentials_request)
        ) do
      {first_registration, first_credentials_request, last_connection, last_disconnection}
    end
  end
end
