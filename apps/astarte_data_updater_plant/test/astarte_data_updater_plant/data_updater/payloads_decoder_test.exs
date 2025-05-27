#
# This file is part of Astarte.
#
# Copyright 2018 - 2023 SECO Mind Srl
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

defmodule Astarte.DataUpdaterPlant.PayloadsDecoderTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias Astarte.Core.Interface
  alias Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder
  alias Astarte.Common.Generators.Timestamp, as: TimestampGenerator
  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator

  test "unset" do
    timestamp = decimicrosecond_timestamp() |> Enum.at(0)

    assert PayloadsDecoder.decode_bson_payload(<<>>, timestamp) == {nil, nil, nil}
  end

  test "deprecated unset" do
    timestamp = decimicrosecond_timestamp() |> Enum.at(0)

    unset_payload = %{"v" => %Cyanide.Binary{data: <<>>, subtype: :generic}} |> Cyanide.encode!()

    assert PayloadsDecoder.decode_bson_payload(unset_payload, timestamp) == {nil, nil, nil}
  end

  property "individual value payloads without metadata and without timestamp" do
    timestamp = decimicrosecond_timestamp() |> Enum.at(0)
    expected_timestamp = timestamp |> div(10_000)

    check all payload <- decoded_payload() do
      encoded_payload = Cyanide.encode!(payload)
      value = Map.fetch!(payload, "v")

      expected_timestamp =
        case Map.fetch(payload, "t") do
          {:ok, explicit_timestamp} -> DateTime.to_unix(explicit_timestamp, :millisecond)
          :error -> expected_timestamp
        end

      expected_metadata = Map.get(payload, "m", %{})

      assert PayloadsDecoder.decode_bson_payload(encoded_payload, timestamp) ==
               {value, expected_timestamp, expected_metadata}
    end
  end

  test "deprecated object aggregation" do
    timestamp = decimicrosecond_timestamp() |> Enum.at(0)
    expected_timestamp = timestamp |> div(10_000)

    object_payload = object_astarte_value() |> Enum.at(0)

    assert PayloadsDecoder.decode_bson_payload(Cyanide.encode!(object_payload), timestamp) ==
             {object_payload, expected_timestamp, %{}}
  end

  property "zlib compressed payload inflate" do
    check all value <- binary() do
      compressed = simple_deflate(value)
      assert PayloadsDecoder.safe_inflate(compressed) == {:ok, value}
    end
  end

  test "zlib inflate does not crash with a payload that is not zlib deflated" do
    non_zlib_deflated_bytes = binary(min_length: 3) |> Enum.at(0)
    assert PayloadsDecoder.safe_inflate(non_zlib_deflated_bytes) == :error
  end

  property "valid device properties paths payload decode" do
    check all introspection <- introspection_map(),
              other_interfaces <- introspection_map(),
              other_interfaces = other_interfaces |> Map.drop(introspection |> Map.keys()),
              introspection_paths <- introspection_paths(introspection),
              other_paths <- introspection_paths(other_interfaces),
              device_properties_string <-
                device_properties_string(MapSet.union(introspection_paths, other_paths)),
              max_runs: 10 do
      assert PayloadsDecoder.parse_device_properties_payload(
               device_properties_string,
               introspection
             ) == {:ok, introspection_paths}
    end
  end

  test "invalid device properties paths payload decode" do
    interface = InterfaceGenerator.interface() |> resize(10) |> Enum.at(0)
    invalid = "#{interface.name};#{interface.name}"
    introspection = %{interface.name => interface.major_version}

    assert PayloadsDecoder.parse_device_properties_payload(invalid, introspection) ==
             {:ok, MapSet.new()}

    invalid_termination = <<0xFFFF::16>>
    rest = binary(min_length: 1) |> Enum.at(0)
    invalid_property = rest <> invalid_termination

    assert PayloadsDecoder.parse_device_properties_payload(invalid_property, introspection) ==
             {:error, :invalid_properties}
  end

  property "valid introspection parsing" do
    check all introspection <- list_of(InterfaceGenerator.interface()) do
      expected_introspection =
        Enum.map(introspection, &{&1.name, &1.major_version, &1.minor_version})

      introspection_string =
        Enum.map_join(expected_introspection, ";", fn {name, major, minor} ->
          interface_string(name, major, minor)
        end)

      assert PayloadsDecoder.parse_introspection(introspection_string) ==
               {:ok, expected_introspection}
    end
  end

  property "invalid introspection strings" do
    check all invalid_introspection <- invalid_introspection_string() do
      assert PayloadsDecoder.parse_introspection(invalid_introspection) ==
               {:error, :invalid_introspection}
    end
  end

  defp simple_deflate(data) do
    zstream = :zlib.open()
    :ok = :zlib.deflateInit(zstream)

    compressed =
      :zlib.deflate(zstream, data, :finish)
      |> :erlang.list_to_binary()

    :ok = :zlib.deflateEnd(zstream)
    :ok = :zlib.close(zstream)

    compressed
  end

  defp decimicrosecond_timestamp do
    gen all timestamp_seconds <- TimestampGenerator.timestamp(),
            decimicroseconds <- integer(0..9999) do
      timestamp_seconds * 10_000 + decimicroseconds
    end
  end

  defp individual_astarte_value do
    base_types = [
      float(),
      integer(),
      boolean(),
      string(:utf8, min_length: 1),
      binary(min_length: 1),
      TimestampGenerator.timestamp()
    ]

    array_types = Enum.map(base_types, &list_of/1)
    individual_types = Enum.concat(base_types, array_types)

    one_of(individual_types)
  end

  defp object_astarte_value do
    map_of(string(:alphanumeric), individual_astarte_value())
  end

  defp astarte_value do
    one_of([individual_astarte_value(), object_astarte_value()])
  end

  defp decoded_payload() do
    value = astarte_value()
    timestamp = map(TimestampGenerator.timestamp(), &DateTime.from_unix!/1)
    metadata = map_of(string(:utf8), string(:utf8))

    optional_map(%{"v" => value, "t" => timestamp, "m" => metadata}, ["t", "m"])
  end

  defp invalid_introspection_string do
    one_of([
      missing_version(),
      invalid_version(),
      invalid_name(),
      extra_numbers(),
      binary(min_length: 1) |> filter(&(not String.valid?(&1)))
    ])
  end

  defp missing_version do
    incomplete_interface =
      gen all interface <- InterfaceGenerator.interface(),
              invalid_string <-
                member_of([
                  "#{interface.name}",
                  "#{interface.name}:#{interface.major_version}",
                  "#{interface.name}:#{interface.minor_version}"
                ]) do
        invalid_string
      end

    list_of(incomplete_interface, min_length: 1)
    |> map(&Enum.join(&1, ";"))
  end

  defp invalid_version do
    not_a_number =
      gen all number <- integer(1..10),
              rest <- string(?a..?z, min_length: 1) do
        "#{number}#{rest}"
      end

    invalid_versions =
      one_of([
        integer(-10..-1),
        not_a_number
      ])

    gen all interfaces <- list_of(InterfaceGenerator.interface(), min_length: 1),
            majors <- list_of(invalid_versions, length: length(interfaces)),
            minors <- list_of(invalid_versions, length: length(interfaces)) do
      Enum.zip_with([interfaces, majors, minors], fn [%{name: name}, major, minor] ->
        interface_string(name, major, minor)
      end)
      |> Enum.join(";")
    end
  end

  defp invalid_name do
    invalid_names =
      string(:utf8)
      |> filter(fn name -> not String.match?(name, Interface.interface_name_regex()) end)

    gen all interfaces <- list_of(InterfaceGenerator.interface(), min_length: 1),
            invalid_names <-
              list_of(invalid_names, length: length(interfaces)) do
      Enum.zip_with(interfaces, invalid_names, fn interface, name ->
        interface_string(name, interface.major_version, interface.minor_version)
      end)
      |> Enum.join(";")
    end
  end

  defp extra_numbers do
    gen all interfaces <- list_of(InterfaceGenerator.interface(), min_length: 1) do
      Enum.map_join(interfaces, ";", fn interface ->
        "#{interface.name}:#{interface.major_version}:#{interface.minor_version}:#{interface.major_version}"
      end)
    end
  end

  defp interface_string(interface_name, major, minor), do: "#{interface_name}:#{major}:#{minor}"

  defp introspection_map do
    list_of(InterfaceGenerator.interface())
    |> map(&Map.new(&1, fn %{name: name, major_version: major} -> {name, major} end))
  end

  defp introspection_paths(introspection_map) do
    introspection_map
    |> Map.new(fn {interface_name, _} -> {interface_name, list_of(path())} end)
    |> fixed_map()
    |> map(fn interface_path_map ->
      interface_path_map
      |> Enum.map(fn {interface_name, paths} -> Enum.map(paths, &{interface_name, &1}) end)
      |> Enum.concat()
      |> MapSet.new()
    end)
  end

  defp device_properties_string(introspection_paths) do
    introspection_paths
    |> Enum.to_list()
    |> shuffle()
    |> map(&Enum.map(&1, fn {interface_name, path} -> interface_name <> path end))
    |> map(&Enum.join(&1, ";"))
  end

  def path do
    gen all tokens <- list_of(string(:alphanumeric, min_length: 1), min_length: 1) do
      "/" <> Enum.join(tokens, "/")
    end
  end
end
