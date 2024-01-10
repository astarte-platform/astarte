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
  use ExUnit.Case
  alias Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder

  test "unset" do
    {:ok, date_time, 0} = DateTime.from_iso8601("2018-03-19T14:15:32+00:00")
    timestamp = DateTime.to_unix(date_time, :millisecond) * 10000 + 123

    assert PayloadsDecoder.decode_bson_payload(<<>>, timestamp) == {nil, nil, nil}
  end

  test "deprecated unset" do
    {:ok, date_time, 0} = DateTime.from_iso8601("2018-03-19T14:15:32+00:00")
    timestamp = DateTime.to_unix(date_time, :millisecond) * 10000 + 123

    unset_payload = Base.decode64!("DQAAAAV2AAAAAAAAAA==")

    assert PayloadsDecoder.decode_bson_payload(unset_payload, timestamp) == {nil, nil, nil}
  end

  test "individual value payloads without metadata and without timestamp" do
    {:ok, date_time, 0} = DateTime.from_iso8601("2018-03-19T14:15:32+00:00")
    timestamp = DateTime.to_unix(date_time, :microsecond) * 10 + 123
    expected_timestamp = DateTime.to_unix(date_time, :millisecond)

    string_payload = Base.decode64!("FAAAAAJ2AAgAAAAjRTVEOTAwAAA=")

    assert PayloadsDecoder.decode_bson_payload(string_payload, timestamp) ==
             {"#E5D900", expected_timestamp, %{}}

    boolean_payload = Base.decode64!("CQAAAAh2AAAA")

    assert PayloadsDecoder.decode_bson_payload(boolean_payload, timestamp) ==
             {false, expected_timestamp, %{}}

    double_payload = Base.decode64!("EAAAAAF2AKqjtujUUds/AA==")

    assert PayloadsDecoder.decode_bson_payload(double_payload, timestamp) ==
             {0.4268696091262948, expected_timestamp, %{}}
  end

  test "individual value payloads with timestamp and without metadata" do
    {:ok, date_time, 0} = DateTime.from_iso8601("2018-02-19T14:15:32+00:00")
    rec_timestamp = DateTime.to_unix(date_time, :microsecond) * 10 + 123
    expected_timestamp = 1_521_464_570_595

    double_payload = Base.decode64!("GwAAAAF2AGZRYzaGqOE/CXQA4/JaPmIBAAAA")

    assert PayloadsDecoder.decode_bson_payload(double_payload, rec_timestamp) ==
             {0.5518218099846706, expected_timestamp, %{}}
  end

  test "individual value payloads with metadata and without timestamp" do
    {:ok, date_time, 0} = DateTime.from_iso8601("2018-02-19T14:15:32+00:00")
    rec_timestamp = DateTime.to_unix(date_time, :microsecond) * 10 + 123
    expected_timestamp = DateTime.to_unix(date_time, :millisecond)

    double_payload =
      Base.decode64!("MAAAAANtAB0AAAACbWV0YTEAAgAAAGEAEG1ldGEyAAIAAAAAAXYAZlFjNoao4T8A")

    assert PayloadsDecoder.decode_bson_payload(double_payload, rec_timestamp) ==
             {0.5518218099846706, expected_timestamp, %{"meta1" => "a", "meta2" => 2}}
  end

  test "deprecated object aggregation" do
    {:ok, date_time, 0} = DateTime.from_iso8601("2018-03-19T14:15:32+00:00")
    timestamp = DateTime.to_unix(date_time, :microsecond) * 10 + 123
    expected_timestamp = DateTime.to_unix(date_time, :millisecond)

    object_payload =
      "SwAAAAViaW4ABAAAAAAAAQIDCHRlc3QxAAECdGVzdDIACgAAAMSnZcWCxYLDuAABdGVzdDMAAAAAAAAAFEAJdG0AaGcvSGIBAAAA"
      |> Base.decode64!()

    assert PayloadsDecoder.decode_bson_payload(object_payload, timestamp) ==
             {%{
                "test1" => true,
                "test2" => "ħełłø",
                "test3" => 5.0,
                "tm" => DateTime.from_unix!(1_521_629_489_000, :millisecond),
                "bin" => %Cyanide.Binary{subtype: :generic, data: <<0, 1, 2, 3>>}
              }, expected_timestamp, %{}}
  end

  test "object aggregation without timestamp and without metadata" do
    {:ok, date_time, 0} = DateTime.from_iso8601("2018-03-19T14:15:32+00:00")
    timestamp = DateTime.to_unix(date_time, :microsecond) * 10 + 123
    expected_timestamp = DateTime.to_unix(date_time, :millisecond)

    object_payload =
      "UwAAAAN2AEsAAAAFYmluAAQAAAAAAAECAwh0ZXN0MQABAnRlc3QyAAoAAADEp2XFgsWCw7gAAXRlc3QzAAAAAAAAABRACXRtAGhnL0hiAQAAAAA="
      |> Base.decode64!()

    assert PayloadsDecoder.decode_bson_payload(object_payload, timestamp) ==
             {%{
                "test1" => true,
                "test2" => "ħełłø",
                "test3" => 5.0,
                "tm" => DateTime.from_unix!(1_521_629_489_000, :millisecond),
                "bin" => %Cyanide.Binary{subtype: :generic, data: <<0, 1, 2, 3>>}
              }, expected_timestamp, %{}}
  end

  test "object aggregation with timestamp and without metadata" do
    {:ok, date_time, 0} = DateTime.from_iso8601("2018-03-19T14:15:32+00:00")
    timestamp = DateTime.to_unix(date_time, :microsecond) * 10 + 123
    expected_timestamp = 1_521_464_570_595

    object_payload =
      "XgAAAAl0AOPyWj5iAQAAA3YASwAAAAViaW4ABAAAAAAAAQIDCHRlc3QxAAECdGVzdDIACgAAAMSnZcWCxYLDuAABdGVzdDMAAAAAAAAAFEAJdG0AaGcvSGIBAAAAAA=="
      |> Base.decode64!()

    assert PayloadsDecoder.decode_bson_payload(object_payload, timestamp) ==
             {%{
                "test1" => true,
                "test2" => "ħełłø",
                "test3" => 5.0,
                "tm" => DateTime.from_unix!(1_521_629_489_000, :millisecond),
                "bin" => %Cyanide.Binary{subtype: :generic, data: <<0, 1, 2, 3>>}
              }, expected_timestamp, %{}}
  end

  test "object aggregation with timestamp and metadata" do
    {:ok, date_time, 0} = DateTime.from_iso8601("2018-03-19T14:15:32+00:00")
    timestamp = DateTime.to_unix(date_time, :microsecond) * 10 + 123
    expected_timestamp = 1_521_464_570_595

    object_payload =
      "cAAAAANtAA8AAAAQbWV0YQACAAAAAAl0AOPyWj5iAQAAA3YASwAAAAViaW4ABAAAAAAAAQIDCHRlc3QxAAECdGVzdDIACgAAAMSnZcWCxYLDuAABdGVzdDMAAAAAAAAAFEAJdG0AaGcvSGIBAAAAAA=="
      |> Base.decode64!()

    assert PayloadsDecoder.decode_bson_payload(object_payload, timestamp) ==
             {%{
                "test1" => true,
                "test2" => "ħełłø",
                "test3" => 5.0,
                "tm" => DateTime.from_unix!(1_521_629_489_000, :millisecond),
                "bin" => %Cyanide.Binary{subtype: :generic, data: <<0, 1, 2, 3>>}
              }, expected_timestamp, %{"meta" => 2}}
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
end
