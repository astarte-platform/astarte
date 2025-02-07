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
  alias Astarte.DataAccess.DatabaseTestHelper

  @realm "astartetest"

  @xml """
  <?xml version="1.0" encoding="UTF-8"?>
  <astarte>
  <devices>
  <device device_id="yKA3CMd07kWaDyj6aMP4Dg">
  <protocol revision="0" pending_empty_cache="false"/>
  <registration secret_bcrypt_hash="null" first_registration="2019-05-30T13:49:57.045Z"/>
  <credentials inhibit_request="false" cert_serial="324725654494785828109237459525026742139358888604" cert_aki="a8eaf08a797f0b10bb9e7b5dca027ec2571c5ea6" first_credentials_request="2019-05-30T13:49:57.355Z" last_credentials_request_ip="198.51.100.1"/>
  <stats total_received_msgs="64" total_received_bytes="3960" last_connection="2019-05-30T13:49:57.561Z" last_disconnection="2019-05-30T13:51:00.038Z" last_seen_ip="198.51.100.89"/>
  <interfaces>
  <interface name="properties.org" major_version="0" minor_version="1" active="true">
  <property reception_timestamp="2020-01-30T03:26:23.184Z" path="/properties1">42.0</property>
  <property reception_timestamp="2020-01-30T03:26:23.185Z" path="/properties2">This is property string</property>
  </interface>
  <interface name="org.individualdatastreams.values" major_version="0" minor_version="1" active="true">
  <datastream path="/testinstall1">
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
  <interface name="objectdatastreams.org" major_version="0" minor_version="1" active="true">
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
  </astarte>
  """

  setup_all do
    Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
      DatabaseTestHelper.create_test_keyspace(conn)
    end)

    on_exit(fn ->
      Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
        DatabaseTestHelper.drop_test_keyspace(conn)
      end)
    end)

    :ok
  end

  setup do
    Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
      DatabaseTestHelper.seed_data(conn)
    end)
  end

  test "Test import into Cassandra database" do
    PopulateDB.populate(@realm, @xml)
  end
end
