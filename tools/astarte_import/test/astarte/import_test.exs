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

  test "parse a XML document" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <astarte>
      <devices>
        <device device_id="yKA3CMd07kWaDyj6aMP4Dg">
          <interfaces>
            <interface name="org.astarteplatform.Values" major_version="0" minor_version="1">
              <values path="/realValue">
                <value timestamp="2019-05-31T09:12:42.789379Z">0.1</value>
                <value timestamp="2019-05-31T09:13:29.144111Z">0.2</value>
                <value timestamp="2019-05-31T09:13:52.040373Z">0.3</value>
              </values>
            </interface>
          </interfaces>
        </device>
      </devices>
    </astarte>
    """

    xml_fun = fn state, chars ->
      %Import.State{
        device_id: device_id,
        interface: interface,
        path: path,
        timestamp: timestamp,
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

    assert Import.parse(xml, xml_fun, nil) == %{
             "yKA3CMd07kWaDyj6aMP4Dg" => %{
               {"org.astarteplatform.Values", 0, 1} => %{
                 "/realValue" => %{
                   "2019-05-31T09:12:42.789379Z" => '0.1',
                   "2019-05-31T09:13:29.144111Z" => '0.2',
                   "2019-05-31T09:13:52.040373Z" => '0.3'
                 }
               }
             }
           }
  end

  test "parse a chunked XML document" do
    xml_chunk1 = """
    <?xml version="1.0" encoding="UTF-8"?>
    <astarte>
    """

    xml_chunk2 = """
      <devices>
        <device device_id="yKA3CMd07kWaDyj6aMP4Dg">
          <interfaces>
            <interface name="org.astarteplatform.Values" major_version="0" minor_version="1">
              <values path="/realValue">
                <value timestamp="2019-05-31T09:12:42.789379Z">0.1</value>
                <value timestamp="2019-05-31T09:13:29.144111Z">0.2</value>
    """

    xml_chunk3 = """
                <value timestamp="2019-05-31T09:13:52.040373Z">0.3</value>
              </values>
            </interface>
          </interfaces>
        </device>
      </devices>
    """

    xml_chunk4 = """
    </astarte>
    """

    xml_fun = fn state, chars ->
      %Import.State{
        device_id: device_id,
        interface: interface,
        path: path,
        timestamp: timestamp,
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
        :undefined -> {xml_chunk2, [xml_chunk3, xml_chunk4]}
        [] -> {"", nil}
        [next_chunk | input_state] -> {next_chunk, input_state}
      end
    end

    assert Import.parse(xml_chunk1, xml_fun, cont_fun) == %{
             "yKA3CMd07kWaDyj6aMP4Dg" => %{
               {"org.astarteplatform.Values", 0, 1} => %{
                 "/realValue" => %{
                   "2019-05-31T09:12:42.789379Z" => '0.1',
                   "2019-05-31T09:13:29.144111Z" => '0.2',
                   "2019-05-31T09:13:52.040373Z" => '0.3'
                 }
               }
             }
           }
  end
end
