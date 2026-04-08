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
  This module provides generators for Astarte Device.

  See https://hexdocs.pm/astarte_core/Astarte.Core.Device.html
  """
  use ExUnitProperties

  import Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Common.Generators.Ip, as: IpGenerator
  alias Astarte.Common.Generators.Timestamp, as: TimestampGenerator
  alias Astarte.Core.Device
  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Core.Interface

  @doc """
  Generates a valid Astarte Device with pre-created interfaces_bytes
  """
  @spec device() :: StreamData.t(map())
  @spec device(params :: keyword()) :: StreamData.t(map())
  def device(params \\ []) do
    params gen all now <- DateTime.utc_now() |> DateTime.to_unix() |> constant(),
                   id <- id(),
                   last_seen_ip <- last_seen_ip(),
                   last_credentials_request_ip <- last_credentials_request_ip(),
                   inhibit_credentials_request <- inhibit_credentials_request(),
                   last_disconnection <- last_disconnection(now),
                   last_connection <- last_connection(last_disconnection),
                   first_credentials_request <- first_credentials_request(last_connection),
                   first_registration <- first_registration(first_credentials_request),
                   interfaces <-
                     InterfaceGenerator.interface() |> list_of(min_length: 0, max_length: 10),
                   aliases <- aliases(),
                   attributes <- attributes(),
                   params: params do
      {
        total_received_msgs,
        total_received_bytes,
        interfaces_msgs,
        interfaces_bytes
      } = interfaces_data(interfaces)

      %{
        id: id,
        device_id: id,
        encoded_id: Device.encode_device_id(id),
        connected: last_connection >= last_disconnection,
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
        total_received_msgs: total_received_msgs,
        total_received_bytes: total_received_bytes
      }
    end
  end

  @doc """
  Generates a valid Astarte Device id

  See https://docs.astarte-platform.org/astarte/latest/010-design_principles.html#device-id
  """
  @spec id() :: StreamData.t(<<_::128>>)
  def id do
    gen all seq <- binary(length: 16) do
      <<u0::48, _::4, u1::12, _::2, u2::62>> = seq
      <<u0::48, 4::4, u1::12, 2::2, u2::62>>
    end
  end

  @doc """
  Generates a valid Astarte encoded Device id
  """
  @spec encoded_id() :: StreamData.t(String.t())
  def encoded_id, do: id() |> map(&Base.url_encode64(&1, padding: false))

  defp last_seen_ip, do: one_of([nil, IpGenerator.ip(:ipv4)])
  defp last_credentials_request_ip, do: one_of([nil, IpGenerator.ip(:ipv4)])
  defp inhibit_credentials_request, do: boolean()
  # NOTE: dialyzer does not know about the `params gen all` feature which allows
  # to override parameters, so it assumes it is never called with `nil`.
  @dialyzer {:nowarn_function, last_disconnection: 1}
  defp last_disconnection(nil), do: constant(nil)
  defp last_disconnection(max), do: TimestampGenerator.timestamp(max: max)
  defp last_connection(nil), do: constant(nil)
  defp last_connection(max), do: TimestampGenerator.timestamp(max: max)
  defp first_credentials_request(nil), do: constant(nil)
  defp first_credentials_request(max), do: TimestampGenerator.timestamp(max: max)
  defp first_registration(nil), do: constant(nil)
  defp first_registration(max), do: TimestampGenerator.timestamp(max: max)

  defp aliases,
    do:
      one_of([
        nil,
        map_of(string(:alphanumeric, min_length: 1), string(:alphanumeric, min_length: 1))
      ])

  defp attributes,
    do:
      one_of([
        nil,
        map_of(
          string(:alphanumeric, min_length: 1),
          string(:alphanumeric, min_length: 1)
        )
      ])

  # Interface utility functions
  defp interface_row(%Interface{name: name}), do: {name, 0..1 |> Enum.random()}
  defp interface_map([]), do: {0, 0, nil, nil}
  defp interface_map([], acc), do: acc

  defp interface_map([key | tail], {total_msgs, total_bytes, msgs, bytes}) do
    m = Enum.random(1..10_000)
    b = Enum.random(10..10_000)

    acc = {
      total_msgs + m,
      total_bytes + b,
      Map.merge(msgs, %{key => m}),
      Map.merge(bytes, %{key => b})
    }

    interface_map(tail, acc)
  end

  defp interfaces_data([]), do: interface_map([])
  defp interfaces_data(%Interface{} = interface), do: interfaces_data([interface])

  defp interfaces_data(interfaces) when is_list(interfaces) do
    interfaces
    |> Stream.map(&interface_row/1)
    |> Enum.uniq_by(fn {n, _} -> n end)
    |> interface_map({0, 0, %{}, %{}})
  end
end
