#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.DataUpdaterPlant.PayloadsDecoderTest do
  use ExUnit.Case
  alias Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder

  test "unset" do
    {:ok, date_time, 0} = DateTime.from_iso8601("2018-03-19T14:15:32+00:00")
    timestamp = DateTime.to_unix(date_time, :milliseconds) * 10000 + 123

    assert PayloadsDecoder.decode_bson_payload(<<>>, timestamp) == {nil, nil, nil}
  end

  test "deprecated unset" do
    {:ok, date_time, 0} = DateTime.from_iso8601("2018-03-19T14:15:32+00:00")
    timestamp = DateTime.to_unix(date_time, :milliseconds) * 10000 + 123

    unset_payload = Base.decode64!("DQAAAAV2AAAAAAAAAA==")

    assert PayloadsDecoder.decode_bson_payload(unset_payload, timestamp) == {nil, nil, nil}
  end

  test "individual value payloads without metadata and without timestamp" do
    {:ok, date_time, 0} = DateTime.from_iso8601("2018-03-19T14:15:32+00:00")
    timestamp = DateTime.to_unix(date_time, :microseconds) * 10 + 123
    expected_timestamp = DateTime.to_unix(date_time, :milliseconds)

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
    rec_timestamp = DateTime.to_unix(date_time, :microseconds) * 10 + 123
    expected_timestamp = 1_521_464_570_595

    double_payload = Base.decode64!("GwAAAAF2AGZRYzaGqOE/CXQA4/JaPmIBAAAA")

    assert PayloadsDecoder.decode_bson_payload(double_payload, rec_timestamp) ==
             {0.5518218099846706, expected_timestamp, %{}}
  end

  test "individual value payloads with metadata and without timestamp" do
    {:ok, date_time, 0} = DateTime.from_iso8601("2018-02-19T14:15:32+00:00")
    rec_timestamp = DateTime.to_unix(date_time, :microseconds) * 10 + 123
    expected_timestamp = DateTime.to_unix(date_time, :milliseconds)

    double_payload =
      Base.decode64!("MAAAAANtAB0AAAACbWV0YTEAAgAAAGEAEG1ldGEyAAIAAAAAAXYAZlFjNoao4T8A")

    assert PayloadsDecoder.decode_bson_payload(double_payload, rec_timestamp) ==
             {0.5518218099846706, expected_timestamp, %{meta1: "a", meta2: 2}}
  end

  test "deprecated object aggregation" do
    {:ok, date_time, 0} = DateTime.from_iso8601("2018-03-19T14:15:32+00:00")
    timestamp = DateTime.to_unix(date_time, :microseconds) * 10 + 123
    expected_timestamp = DateTime.to_unix(date_time, :milliseconds)

    object_payload =
      "SwAAAAViaW4ABAAAAAAAAQIDCHRlc3QxAAECdGVzdDIACgAAAMSnZcWCxYLDuAABdGVzdDMAAAAAAAAAFEAJdG0AaGcvSGIBAAAA"
      |> Base.decode64!()

    assert PayloadsDecoder.decode_bson_payload(object_payload, timestamp) ==
             {%{
                test1: true,
                test2: "ħełłø",
                test3: 5.0,
                tm: %Bson.UTC{ms: 1_521_629_489_000},
                bin: Bson.Bin.new(<<0, 1, 2, 3>>, 0)
              }, expected_timestamp, %{}}
  end

  test "object aggregation without timestamp and without metadata" do
    {:ok, date_time, 0} = DateTime.from_iso8601("2018-03-19T14:15:32+00:00")
    timestamp = DateTime.to_unix(date_time, :microseconds) * 10 + 123
    expected_timestamp = DateTime.to_unix(date_time, :milliseconds)

    object_payload =
      "UwAAAAN2AEsAAAAFYmluAAQAAAAAAAECAwh0ZXN0MQABAnRlc3QyAAoAAADEp2XFgsWCw7gAAXRlc3QzAAAAAAAAABRACXRtAGhnL0hiAQAAAAA="
      |> Base.decode64!()

    assert PayloadsDecoder.decode_bson_payload(object_payload, timestamp) ==
             {%{
                test1: true,
                test2: "ħełłø",
                test3: 5.0,
                tm: %Bson.UTC{ms: 1_521_629_489_000},
                bin: Bson.Bin.new(<<0, 1, 2, 3>>, 0)
              }, expected_timestamp, %{}}
  end

  test "object aggregation with timestamp and without metadata" do
    {:ok, date_time, 0} = DateTime.from_iso8601("2018-03-19T14:15:32+00:00")
    timestamp = DateTime.to_unix(date_time, :microseconds) * 10 + 123
    expected_timestamp = 1_521_464_570_595

    object_payload =
      "XgAAAAl0AOPyWj5iAQAAA3YASwAAAAViaW4ABAAAAAAAAQIDCHRlc3QxAAECdGVzdDIACgAAAMSnZcWCxYLDuAABdGVzdDMAAAAAAAAAFEAJdG0AaGcvSGIBAAAAAA=="
      |> Base.decode64!()

    assert PayloadsDecoder.decode_bson_payload(object_payload, timestamp) ==
             {%{
                test1: true,
                test2: "ħełłø",
                test3: 5.0,
                tm: %Bson.UTC{ms: 1_521_629_489_000},
                bin: Bson.Bin.new(<<0, 1, 2, 3>>, 0)
              }, expected_timestamp, %{}}
  end

  test "object aggregation with timestamp and metadata" do
    {:ok, date_time, 0} = DateTime.from_iso8601("2018-03-19T14:15:32+00:00")
    timestamp = DateTime.to_unix(date_time, :microseconds) * 10 + 123
    expected_timestamp = 1_521_464_570_595

    object_payload =
      "cAAAAANtAA8AAAAQbWV0YQACAAAAAAl0AOPyWj5iAQAAA3YASwAAAAViaW4ABAAAAAAAAQIDCHRlc3QxAAECdGVzdDIACgAAAMSnZcWCxYLDuAABdGVzdDMAAAAAAAAAFEAJdG0AaGcvSGIBAAAAAA=="
      |> Base.decode64!()

    assert PayloadsDecoder.decode_bson_payload(object_payload, timestamp) ==
             {%{
                test1: true,
                test2: "ħełłø",
                test3: 5.0,
                tm: %Bson.UTC{ms: 1_521_629_489_000},
                bin: Bson.Bin.new(<<0, 1, 2, 3>>, 0)
              }, expected_timestamp, %{meta: 2}}
  end

  test "payload deflate" do
    short_message = "SHORT MESSAGE"
    compressed = simple_deflate(short_message)

    assert PayloadsDecoder.safe_inflate(compressed) == short_message

    empty_message = ""
    compressed = simple_deflate(empty_message)

    assert PayloadsDecoder.safe_inflate(compressed) == empty_message

    rand_bytes = :crypto.strong_rand_bytes(10_485_760 - 1)
    compressed = simple_deflate(rand_bytes)

    assert PayloadsDecoder.safe_inflate(compressed) == rand_bytes

    rand_bytes_bigger = :crypto.strong_rand_bytes(10_485_760)
    compressed = simple_deflate(rand_bytes_bigger)

    assert PayloadsDecoder.safe_inflate(compressed) == :error

    zeroed_bytes =
      Enum.reduce(0..10_485_758, <<>>, fn _i, acc ->
        [0 | acc]
      end)
      |> :erlang.list_to_binary()

    compressed = simple_deflate(zeroed_bytes)

    assert PayloadsDecoder.safe_inflate(compressed) == zeroed_bytes

    compressed = simple_deflate(zeroed_bytes <> <<0>>)

    assert PayloadsDecoder.safe_inflate(compressed) == :error
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
