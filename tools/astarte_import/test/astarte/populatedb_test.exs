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

defmodule Astarte.PopulateDBTest do
  use ExUnit.Case
  alias Astarte.Import.PopulateDB

  @realm "test"

  @xml """
  <?xml version="1.0" encoding="UTF-8"?>
  <astarte>
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
        <interface name="org.astarteplatform.Values" major_version="0" minor_version="1"
         active="true">
            <datastream path="/realValue">
              <value reception_timestamp="2019-05-31T09:12:42.789379Z">0.1</value>
              <value reception_timestamp="2019-05-31T09:13:29.144111Z">0.2</value>
              <value reception_timestamp="2019-05-31T09:13:52.040373Z">0.3</value>
            </datastream>
          </interface>
          <interface name="org.astarteplatform.ValuesXYZ" major_version="0" minor_version="1" active="true">
            <datastream path="/realValues">
              <object reception_timestamp="2019-06-11T13:24:03.200820Z">
                <item name="/x">0.1</item>
                <item name="/y">0.2</item>
                <item name="/z">0.3</item>
              </object>
              <object reception_timestamp="2019-06-11T13:26:28.994144Z">
                <item name="/x">1.0</item>
                <item name="/y">2.0</item>
                <item name="/z">3.0</item>
              </object>
              <object reception_timestamp="2019-06-11T13:26:44.218092Z">
                <item name="/x">10</item>
                <item name="/y">20</item>
                <item name="/z">30</item>
              </object>
            </datastream>
          </interface>
          <interface name="org.astarteplatform.PropertyValue" major_version="0" minor_version="1" active="true">
            <property path="/realValue" reception_timestamp="2019-06-12T14:45:49.706034Z">4.2</property>
          </interface>
        </interfaces>
      </device>
    </devices>
  </astarte>
  """

  test "Test import into Cassandra database" do
    PopulateDB.populate(@realm, @xml)
  end
end
