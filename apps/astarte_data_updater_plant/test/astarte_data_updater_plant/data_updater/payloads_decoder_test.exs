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
  alias Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder
  alias Astarte.Common.Generators.Timestamp, as: TimestampGenerator

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

  test "zlib compressed payload inflate" do
    short_message = "SHORT MESSAGE"
    compressed = simple_deflate(short_message)

    assert PayloadsDecoder.safe_inflate(compressed) == {:ok, short_message}

    empty_message = ""
    compressed = simple_deflate(empty_message)

    assert PayloadsDecoder.safe_inflate(compressed) == {:ok, empty_message}

    rand_bytes = :crypto.strong_rand_bytes(10_485_760 - 1)
    compressed = simple_deflate(rand_bytes)

    assert PayloadsDecoder.safe_inflate(compressed) == {:ok, rand_bytes}

    rand_bytes_bigger = :crypto.strong_rand_bytes(10_485_760)
    compressed = simple_deflate(rand_bytes_bigger)

    assert PayloadsDecoder.safe_inflate(compressed) == :error

    zeroed_bytes =
      Enum.reduce(0..10_485_758, <<>>, fn _i, acc ->
        [0 | acc]
      end)
      |> :erlang.list_to_binary()

    compressed = simple_deflate(zeroed_bytes)

    assert PayloadsDecoder.safe_inflate(compressed) == {:ok, zeroed_bytes}

    compressed = simple_deflate(zeroed_bytes <> <<0>>)

    assert PayloadsDecoder.safe_inflate(compressed) == :error
  end

  test "zlib inflate does not crash with a payload that is not zlib deflated" do
    non_zlib_deflated_bytes = <<120, 185, 188, 158, 201, 217, 87, 12, 0, 251>>
    assert PayloadsDecoder.safe_inflate(non_zlib_deflated_bytes) == :error
  end

  test "device properties paths payload decode" do
    payload = "com.test.LCDMonitor/time/to;com.test.LCDMonitor/weekSchedule/10/start"
    introspection = %{"com.test.LCDMonitor" => 1}

    keep_paths =
      MapSet.new([
        {"com.test.LCDMonitor", "/time/to"},
        {"com.test.LCDMonitor", "/weekSchedule/10/start"}
      ])

    assert PayloadsDecoder.parse_device_properties_payload(payload, introspection) ==
             {:ok, keep_paths}

    introspection2 = %{"com.test.LCDMonitor" => 1, "com.example.A" => 2}

    assert PayloadsDecoder.parse_device_properties_payload(payload, introspection2) ==
             {:ok, keep_paths}

    payload2 = "com.test.LCDMonitor/time/to"

    keep_paths2 =
      MapSet.new([
        {"com.test.LCDMonitor", "/time/to"}
      ])

    assert PayloadsDecoder.parse_device_properties_payload(payload2, introspection2) ==
             {:ok, keep_paths2}

    # TODO: probably here would be a good idea to fail
    assert PayloadsDecoder.parse_device_properties_payload(payload, %{}) == {:ok, MapSet.new()}

    assert PayloadsDecoder.parse_device_properties_payload("", introspection) ==
             {:ok, MapSet.new()}

    assert PayloadsDecoder.parse_device_properties_payload("", %{}) == {:ok, MapSet.new()}

    invalid = "com.test.LCDMonitor;com.test.LCDMonitor"

    assert PayloadsDecoder.parse_device_properties_payload(invalid, introspection2) ==
             {:ok, MapSet.new()}

    assert PayloadsDecoder.parse_device_properties_payload(<<0xFFFF::16>>, %{"something" => 1}) ==
             {:error, :invalid_properties}
  end

  test "valid introspection parsing" do
    parsed1 = [{"good.introspection", 1, 0}]
    introspection1 = "good.introspection:1:0"
    assert PayloadsDecoder.parse_introspection(introspection1) == {:ok, parsed1}

    parsed2 = [{"good.introspection", 1, 0}, {"other.good.introspection", 0, 3}]
    introspection2 = "good.introspection:1:0;other.good.introspection:0:3"
    assert PayloadsDecoder.parse_introspection(introspection2) == {:ok, parsed2}

    assert PayloadsDecoder.parse_introspection("") == {:ok, []}
  end

  test "invalid introspection strings" do
    invalid = {:error, :invalid_introspection}

    assert PayloadsDecoder.parse_introspection("a;b;c") == invalid
    assert PayloadsDecoder.parse_introspection("a:0:1;b:1:0;c") == invalid
    assert PayloadsDecoder.parse_introspection("a:0:1z;b:1:0") == invalid
    assert PayloadsDecoder.parse_introspection("a:0:1z:b:1:0") == invalid
    assert PayloadsDecoder.parse_introspection("a:0:-1:b:1:0") == invalid
    assert PayloadsDecoder.parse_introspection(<<0xFFFF::16>>) == invalid
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
end
