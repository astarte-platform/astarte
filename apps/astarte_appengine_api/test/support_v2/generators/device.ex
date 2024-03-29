defmodule Astarte.Test.Generators.Device do
  alias Astarte.Core.Device
  alias Astarte.Test.Generators.Common, as: CommonGenerator
  alias Astarte.Test.Generators.DateTime, as: DateTimeGenerator
  use ExUnitProperties

  def id() do
    gen all seq <- binary(length: 16) do
      <<u0::48, _::4, u1::12, _::2, u2::62>> = seq
      <<u0::48, 4::4, u1::12, 2::2, u2::62>>
    end
  end

  def encoded_id() do
    gen all id <- id() do
      Base.url_encode64(id, padding: false)
    end
  end

  defp received do
    gen all msgs <- integer(1..10_000),
            bytes <- integer(10..10_000) do
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

  defp dates() do
    time_zone = "Etc/UTC"

    gen all last_disconnection <-
              DateTimeGenerator.date_time(max: DateTime.now!(time_zone) |> DateTime.to_unix()),
            last_connection <-
              DateTimeGenerator.date_time(max: DateTime.now!(time_zone) |> DateTime.to_unix()),
            first_credentials_request <-
              DateTimeGenerator.date_time(max: last_connection |> DateTime.to_unix()),
            first_registration <-
              DateTimeGenerator.date_time(max: first_credentials_request |> DateTime.to_unix()) do
      {first_registration, first_credentials_request, last_connection, last_disconnection}
    end
  end

  def device(interfaces: interfaces) do
    gen all id <- id(),
            last_seen_ip <- CommonGenerator.ip(),
            last_credentials_request_ip <- CommonGenerator.ip(),
            inhibit_credentials_request <- boolean(),
            {
              first_registration,
              first_credentials_request,
              last_connection,
              last_disconnection
            } <- dates(),
            {interfaces_msgs, interfaces_bytes} <-
              interfaces
              |> Enum.map(fn i -> i.name end)
              |> interface_maps(),
            aliases <- aliases(),
            attributes <- attributes() do
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
end
