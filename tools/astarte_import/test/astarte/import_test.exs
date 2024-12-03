# Copyright 2019 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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
      <device device_id="yKA3CMd07kWaDyj6aMP4Dg">
        <protocol revision="0" pending_empty_cache="false" />
        <registration
         secret_bcrypt_hash="$2b$12$bKly9EEKmxfVyDeXjXu1vOebWgr34C8r4IHd9Cd.34Ozm0TWVo1Ve"
         first_registration="2019-05-30T13:49:57.045000Z" />
        <credentials inhibit_request="false"
         cert_serial="324725654494785828109237459525026742139358888604"
         cert_aki="a8eaf08a797f0b10bb9e7b5dca027ec2571c5ea6"
         first_credentials_request="2019-05-30T13:49:57.355000Z"
         last_credentials_request_ip="198.51.100.1" />
        <stats total_received_msgs="64" total_received_bytes="3960"
         last_connection="2019-05-30T13:49:57.561000Z" last_disconnection="2019-05-30T13:51:00.038000Z"
         last_seen_ip="198.51.100.89"/>

        <interfaces>
          <interface name="org.astarteplatform.Values" major_version="0" minor_version="1" active="true">
            <datastream path="/realValue">
              <value reception_timestamp="2019-05-31T09:12:42.789379Z">0.1</value>
              <value reception_timestamp="2019-05-31T09:13:29.144111Z">0.2</value>
  """

  @xml_chunk3 """
              <value reception_timestamp="2019-05-31T09:13:52.040373Z">0.3</value>
            </datastream>
          </interface>
        <interface name="org.astarteplatform.Values" major_version="1" minor_version="0" active="false"/>
        </interfaces>
        <interface name="org.astarteplatform.Properties" major_version="1" minor_version="1" active="true">
          <property path="/hello" reception_timestamp="2019-06-12T14:45:49.706034Z">world</property>
          <property path="/items/1/value" reception_timestamp="2019-06-12T14:45:49.706034Z">1.1</property>
          <property path="/items/1/string" reception_timestamp="2019-06-12T14:45:49.706034Z">string 1</property>
          <property path="/items/2/value" reception_timestamp="2019-06-12T14:45:49.706034Z">2.2</property>
          <property path="/items/2/string" reception_timestamp="2019-06-12T14:45:49.706034Z">string 2</property>
        </interface>
        <interface name="org.astarteplatform.ObjectAggregated" major_version="2" minor_version="0" active="true">
          <datastream path="/obj">
            <object reception_timestamp="2019-06-11T10:40:47.162207Z">
              <item name="/val1">true</item>
              <item name="/val2">1</item>
            </object>
            <object reception_timestamp="2019-06-11T10:43:19.599735Z">
              <item name="/val1">false</item>
              <item name="/val2">2</item>
            </object>
          </datastream>
        </interface>
      </device>
    </devices>
  """

  @xml_chunk4 """
  </astarte>"
  """

  @xml @xml_chunk1 <> @xml_chunk2 <> @xml_chunk3 <> @xml_chunk4

  @populated_map %{
    "yKA3CMd07kWaDyj6aMP4Dg" => %{
      {"org.astarteplatform.Values", 0, 1} => %{
        "/realValue" => %{
          "2019-05-31T09:12:42.789379Z" => '0.1',
          "2019-05-31T09:13:29.144111Z" => '0.2',
          "2019-05-31T09:13:52.040373Z" => '0.3'
        }
      },
      {"org.astarteplatform.Properties", 1, 1} => %{
        "/hello" => 'world',
        "/items/1/value" => '1.1',
        "/items/1/string" => 'string 1',
        "/items/2/value" => '2.2',
        "/items/2/string" => 'string 2'
      },
      {"org.astarteplatform.ObjectAggregated", 2, 0} => %{
        "/obj" => %{
          "2019-06-11T10:40:47.162207Z" => %{
            "/val1" => 'true',
            "/val2" => '1'
          },
          "2019-06-11T10:43:19.599735Z" => %{
            "/val1" => 'false',
            "/val2" => '2'
          }
        }
      },
      device_status: %{
        introspection: %{
          "org.astarteplatform.Values" => {0, 1},
          "org.astarteplatform.Properties" => {1, 1},
          "org.astarteplatform.ObjectAggregated" => {2, 0}
        },
        old_introspection: %{{"org.astarteplatform.Values", 1} => 0},
        pending_empty_cache: false,
        credentials_secret: "$2b$12$bKly9EEKmxfVyDeXjXu1vOebWgr34C8r4IHd9Cd.34Ozm0TWVo1Ve",
        first_registration: elem(DateTime.from_iso8601("2019-05-30T13:49:57.045000Z"), 1),
        cert_aki: "a8eaf08a797f0b10bb9e7b5dca027ec2571c5ea6",
        cert_serial: "324725654494785828109237459525026742139358888604",
        first_credentials_request: elem(DateTime.from_iso8601("2019-05-30T13:49:57.355000Z"), 1),
        last_credentials_request_ip: {198, 51, 100, 1},
        total_received_msgs: 64,
        total_received_bytes: 3960,
        last_connection: elem(DateTime.from_iso8601("2019-05-30T13:49:57.561000Z"), 1),
        last_disconnection: elem(DateTime.from_iso8601("2019-05-30T13:51:00.038000Z"), 1),
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
      cert_aki: cert_aki,
      cert_serial: cert_serial,
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
      cert_aki: cert_aki,
      cert_serial: cert_serial,
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

    new_data = update_in(data, [device_id, :device_status], &(&1 || device_status))

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
      |> update_in([device_id, interface], &(&1 || %{}))
      |> put_in([device_id, interface, path], chars)

    %Import.State{state | data: new_data}
  end
end
