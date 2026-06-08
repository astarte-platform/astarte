#
# This file is part of Astarte.
#
# Copyright 2019 - 2025 SECO Mind Srl
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

defmodule Astarte.ImportTest do
  use ExUnit.Case
  alias Astarte.Import

  @xml_chunk1 """
  <?xml version="1.0" encoding="UTF-8"?>
  <astarte>
  """

  @xml_chunk2 """
    <devices>
        <device device_id="yKA3CMd07kWaDyj6aMP4Dg" connected="false">
            <protocol revision="0" pending_empty_cache="false" />
            <registration
                credentials_secret="$2b$12$bKly9EEKmxfVyDeXjXu1vOebWgr34C8r4IHd9Cd.34Ozm0TWVo1Ve"
                first_registration="2019-05-30T13:49:57.045Z" />
            <credentials inhibit_request="false"
                cert_serial="324725654494785828109237459525026742139358888604"
                cert_aki="a8eaf08a797f0b10bb9e7b5dca027ec2571c5ea6"
                first_credentials_request="2019-05-30T13:49:57.355Z"
                last_credentials_request_ip="198.51.100.1" />
            <capabilities purge_properties_compression_format="0" />
            <stats total_received_msgs="64" total_received_bytes="3960"
                last_connection="2019-05-30T13:49:57.561Z"
                last_disconnection="2019-05-30T13:51:00.038Z" last_seen_ip="198.51.100.89" />
            <attributes>
                <attribute name="attribute" value="value_of_attribute" />
            </attributes>
            <aliases>
                <alias name="alias" as="value_of_alias" />
            </aliases>
            <interfaces>
                <interface name="objectdatastreams.org" major_version="0" minor_version="1"
                    active="false">
                    <datastream path="/objectendpoint1">
                        <object reception_timestamp="2019-06-11T13:24:03.200Z">
                            <item name="/y">2</item>
                            <item name="/x">45.0</item>
                        </object>
                        <object reception_timestamp="2019-06-11T13:26:28.994Z">
                            <item name="/y">555</item>
                            <item name="/x">1.0</item>
                        </object>
                        <object reception_timestamp="2019-06-11T13:26:44.218Z">
                            <item name="/y">22</item>
                            <item name="/x">488.0</item>
                        </object>
                    </datastream>
                </interface>
                <interface name="properties.org" major_version="0" minor_version="1" active="true">
                    <property reception_timestamp="2020-01-30T03:26:23.184Z" path="/properties1">
                        42.0</property>
                    <property reception_timestamp="2020-01-30T03:26:23.185Z" path="/properties2">This
                        is property string</property>
                </interface>
                <interface name="org.individualdatastreams.values" major_version="0"
                    minor_version="1" active="true">
                    <datastream path="/testinstall1">
  """

  @xml_chunk3 """
                        <value reception_timestamp="2019-05-31T09:12:42.789Z">0.1</value>
                        <value reception_timestamp="2019-05-31T09:13:29.144Z">0.2</value>
                        <value reception_timestamp="2019-05-31T09:13:52.040Z">0.3</value>
                    </datastream>
                    <datastream path="/testinstall2">
                        <value reception_timestamp="2019-05-31T09:12:42.789Z">3</value>
                        <value reception_timestamp="2019-05-31T09:13:52.040Z">4</value>
                    </datastream>
                    <datastream path="/testinstall3">
                        <value reception_timestamp="2019-05-31T09:12:42.789Z">true</value>
                        <value reception_timestamp="2019-05-31T09:13:29.144Z">false</value>
                        <value reception_timestamp="2019-05-31T09:13:52.040Z">true</value>
                    </datastream>
                    <datastream path="/testinstall4">
                        <value reception_timestamp="2019-05-31T09:12:42.789Z">This is the data1</value>
                        <value reception_timestamp="2019-05-31T09:13:29.144Z">This is the data2</value>
                        <value reception_timestamp="2019-05-31T09:13:52.040Z">This is the data3</value>
                    </datastream>
                    <datastream path="/testinstall5">
                        <value reception_timestamp="2019-05-31T09:12:42.789Z">3244325554</value>
                        <value reception_timestamp="2019-05-31T09:13:29.144Z">4885959589</value>
                    </datastream>
                </interface>
                <interface name="objectdatastreams.org" major_version="1" minor_version="0"
                    active="true">
                    <datastream path="/objectendpoint1">
                        <object reception_timestamp="2019-06-11T13:24:03.200Z">
                            <item name="/y">2</item>
                            <item name="/x">45.0</item>
                            <item name="/d">78787985785</item>
                        </object>
                        <object reception_timestamp="2019-06-11T13:26:28.994Z">
                            <item name="/y">555</item>
                            <item name="/x">1.0</item>
                            <item name="/d">747989859</item>
                        </object>
                        <object reception_timestamp="2019-06-11T13:26:44.218Z">
                            <item name="/y">22</item>
                            <item name="/x">488.0</item>
                            <item name="/d">747847748</item>
                        </object>
                    </datastream>
                </interface>
            </interfaces>
        </device>
    </devices>
  """

  @xml_chunk4 """
  </astarte>"
  """

  @xml @xml_chunk1 <> @xml_chunk2 <> @xml_chunk3 <> @xml_chunk4

  @populated_map %{
    "yKA3CMd07kWaDyj6aMP4Dg" => %{
      {"org.individualdatastreams.values", 0, 1} => %{
        "/testinstall1" => %{
          "2019-05-31T09:12:42.789Z" => ~c"0.1",
          "2019-05-31T09:13:29.144Z" => ~c"0.2",
          "2019-05-31T09:13:52.040Z" => ~c"0.3"
        },
        "/testinstall2" => %{
          "2019-05-31T09:12:42.789Z" => ~c"3",
          "2019-05-31T09:13:52.040Z" => ~c"4"
        },
        "/testinstall3" => %{
          "2019-05-31T09:12:42.789Z" => ~c"true",
          "2019-05-31T09:13:29.144Z" => ~c"false",
          "2019-05-31T09:13:52.040Z" => ~c"true"
        },
        "/testinstall4" => %{
          "2019-05-31T09:12:42.789Z" => ~c"This is the data1",
          "2019-05-31T09:13:29.144Z" => ~c"This is the data2",
          "2019-05-31T09:13:52.040Z" => ~c"This is the data3"
        },
        "/testinstall5" => %{
          "2019-05-31T09:12:42.789Z" => ~c"3244325554",
          "2019-05-31T09:13:29.144Z" => ~c"4885959589"
        }
      },
      {"properties.org", 0, 1} => %{
        "/properties1" => ~c"42.0",
        "/properties2" => ~c"This is property string"
      },
      {"objectdatastreams.org", 0, 1} => %{
        "/objectendpoint1" => %{
          "2019-06-11T13:24:03.200Z" => %{"/x" => ~c"45.0", "/y" => ~c"2"},
          "2019-06-11T13:26:28.994Z" => %{"/x" => ~c"1.0", "/y" => ~c"555"},
          "2019-06-11T13:26:44.218Z" => %{"/x" => ~c"488.0", "/y" => ~c"22"}
        }
      },
      {"objectdatastreams.org", 1, 0} => %{
        "/objectendpoint1" => %{
          "2019-06-11T13:24:03.200Z" => %{
            "/d" => ~c"78787985785",
            "/x" => ~c"45.0",
            "/y" => ~c"2"
          },
          "2019-06-11T13:26:28.994Z" => %{"/d" => ~c"747989859", "/x" => ~c"1.0", "/y" => ~c"555"},
          "2019-06-11T13:26:44.218Z" => %{
            "/d" => ~c"747847748",
            "/x" => ~c"488.0",
            "/y" => ~c"22"
          }
        }
      },
      device_status: %{
        connected: false,
        introspection: %{
          "properties.org" => {0, 1},
          "org.individualdatastreams.values" => {0, 1},
          "objectdatastreams.org" => {1, 0}
        },
        aliases: %{"alias" => "value_of_alias"},
        attributes: %{"attribute" => "value_of_attribute"},
        capabilities: %{"purge_properties_compression_format" => 0},
        old_introspection: %{{"objectdatastreams.org", 0} => 1},
        pending_empty_cache: false,
        credentials_secret: "$2b$12$bKly9EEKmxfVyDeXjXu1vOebWgr34C8r4IHd9Cd.34Ozm0TWVo1Ve",
        first_registration: elem(DateTime.from_iso8601("2019-05-30T13:49:57.045Z"), 1),
        cert_aki: "a8eaf08a797f0b10bb9e7b5dca027ec2571c5ea6",
        cert_serial: "324725654494785828109237459525026742139358888604",
        first_credentials_request: elem(DateTime.from_iso8601("2019-05-30T13:49:57.355Z"), 1),
        last_credentials_request_ip: {198, 51, 100, 1},
        total_received_msgs: 64,
        total_received_bytes: 3960,
        last_connection: elem(DateTime.from_iso8601("2019-05-30T13:49:57.561Z"), 1),
        last_disconnection: elem(DateTime.from_iso8601("2019-05-30T13:51:00.038Z"), 1),
        last_seen_ip: {198, 51, 100, 89}
      }
    }
  }

  test "parse a XML document" do
    got_end_of_value_fun = fn state, chars ->
      %Import.State{
        device_id: device_id,
        interface: interface,
        path: path,
        reception_timestamp: timestamp,
        data: data
      } = state

      timestamp_s = DateTime.to_iso8601(timestamp)

      new_data =
        (data || %{})
        |> update_in([device_id], &(&1 || %{}))
        |> update_in([device_id, interface], &(&1 || %{}))
        |> update_in([device_id, interface, path], &(&1 || %{}))
        |> put_in([device_id, interface, path, timestamp_s], chars)

      %Import.State{state | data: new_data}
    end

    assert Import.parse(@xml,
             got_end_of_value_fun: got_end_of_value_fun,
             got_end_of_object_fun: &got_end_of_object/2,
             got_end_of_property_fun: &got_end_of_property/2,
             got_device_end_fun: &got_device_end/1
           ) ==
             @populated_map
  end

  test "parse a chunked XML document" do
    got_end_of_value_fun = fn state, chars ->
      %Import.State{
        device_id: device_id,
        interface: interface,
        path: path,
        reception_timestamp: timestamp,
        data: data
      } = state

      timestamp_s = DateTime.to_iso8601(timestamp)

      new_data =
        (data || %{})
        |> update_in([device_id], &(&1 || %{}))
        |> update_in([device_id], &(&1 || %{}))
        |> update_in([device_id, interface], &(&1 || %{}))
        |> update_in([device_id, interface, path], &(&1 || %{}))
        |> put_in([device_id, interface, path, timestamp_s], chars)

      %Import.State{state | data: new_data}
    end

    cont_fun = fn state ->
      case state do
        :undefined -> {@xml_chunk2, [@xml_chunk3, @xml_chunk4]}
        [] -> {"", nil}
        [next_chunk | input_state] -> {next_chunk, input_state}
      end
    end

    assert Import.parse(@xml_chunk1,
             got_end_of_value_fun: got_end_of_value_fun,
             got_end_of_object_fun: &got_end_of_object/2,
             got_end_of_property_fun: &got_end_of_property/2,
             continuation_fun: cont_fun,
             got_device_end_fun: &got_device_end/1
           ) ==
             @populated_map
  end

  defp got_device_end(state) do
    %Import.State{
      data: data,
      device_id: device_id,
      connected: connected,
      cert_aki: cert_aki,
      cert_serial: cert_serial,
      aliases: aliases,
      attributes: attributes,
      capabilities: capabilities,
      credentials_secret: credentials_secret,
      first_credentials_request: first_credentials_request,
      first_registration: first_registration,
      introspection: introspection,
      last_connection: last_connection,
      last_credentials_request_ip: last_credentials_request_ip,
      last_disconnection: last_disconnection,
      last_seen_ip: last_seen_ip,
      old_introspection: old_introspection,
      pending_empty_cache: pending_empty_cache,
      total_received_msgs: total_received_msgs,
      total_received_bytes: total_received_bytes
    } = state

    device_status = %{
      connected: connected,
      cert_aki: cert_aki,
      cert_serial: cert_serial,
      aliases: aliases,
      attributes: attributes,
      capabilities: capabilities,
      credentials_secret: credentials_secret,
      first_credentials_request: first_credentials_request,
      first_registration: first_registration,
      introspection: introspection,
      last_connection: last_connection,
      last_credentials_request_ip: last_credentials_request_ip,
      last_disconnection: last_disconnection,
      last_seen_ip: last_seen_ip,
      old_introspection: old_introspection,
      pending_empty_cache: pending_empty_cache,
      total_received_msgs: total_received_msgs,
      total_received_bytes: total_received_bytes
    }

    new_data =
      update_in(
        data,
        [device_id, :device_status],
        &(&1 || device_status)
      )

    %Import.State{state | data: new_data}
  end

  defp got_end_of_object(state, obj) do
    %Import.State{
      device_id: device_id,
      interface: interface,
      path: path,
      reception_timestamp: timestamp,
      data: data
    } = state

    timestamp_s = DateTime.to_iso8601(timestamp)

    new_data =
      (data || %{})
      |> update_in([device_id], &(&1 || %{}))
      |> update_in([device_id], &(&1 || %{}))
      |> update_in([device_id, interface], &(&1 || %{}))
      |> update_in([device_id, interface, path], &(&1 || %{}))
      |> put_in([device_id, interface, path, timestamp_s], obj)

    %Import.State{state | data: new_data}
  end

  defp got_end_of_property(state, chars) do
    %Import.State{
      device_id: device_id,
      interface: interface,
      path: path,
      data: data
    } = state

    new_data =
      (data || %{})
      |> update_in([device_id], &(&1 || %{}))
      |> update_in([device_id], &(&1 || %{}))
      |> update_in([device_id, interface], &(&1 || %{}))
      |> put_in([device_id, interface, path], chars)

    %Import.State{state | data: new_data}
  end
end
