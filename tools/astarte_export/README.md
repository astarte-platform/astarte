<!--
Copyright 2019 SECO Mind Srl

SPDX-License-Identifier: Apache-2.0
-->

# astarte_export

## ⚠ Warning

This tool is still in alpha phase, don't rely on it for critical migrations.

Astarte Export is an easy to use tool that allows to exporting all the devices and data from an existing Astarte realm to XML format.

```iex
iex(astarte_export@127.0.0.1)6> Astarte.Export.export_realm_data("test", "test.xml")
level=info ts=2020-02-03T03:57:21.412+00:00 msg="Export started." module=Astarte.Export function=generate_xml/2 realm=test tag=export_started
level=info ts=2020-02-03T03:57:21.413+00:00 msg="Connecting to \"172.23.0.3\":\"9042\" cassandra database." module=Astarte.Export.FetchData.Queries function=get_connection/0
level=info ts=2020-02-03T03:57:21.414+00:00 msg="Connected to database." module=Astarte.Export.FetchData.Queries function=get_connection/0
level=info ts=2020-02-03T03:57:21.437+00:00 msg="Export Completed." module=Astarte.Export function=generate_xml/2 realm=test tag=export_completed
{:ok, :export_completed}
iex(astarte_export@127.0.0.1)7>
```
The exported realm data is captured in xml_format as below.

```xml
<astarte>
<devices>
<device device_id="yKA3CMd07kWaDyj6aMP4Dg">
  <protocol pending_empty_cache="false" revision="0"></protocol>
  <registration first_registration="2019-05-30T13:49:57.045Z" secret_bcrypt_hash="$2b$12$bKly9EEKmxfVyDeXjXu1vOebWgr34C8r4IHd9Cd.34Ozm0TWVo1Ve"></registration>
  <credentials cert_aki="a8eaf08a797f0b10bb9e7b5dca027ec2571c5ea6" cert_serial="324725654494785828109237459525026742139358888604" first_credentials_request="2019-05-30T13:49:57.355Z" inhibit_request="false"></credentials>
  <stats last_connection="2019-05-30T13:49:57.561Z" last_disconnection="2019-05-30T13:51:00.038Z" last_seen_ip="198.51.100.89" total_received_bytes="3960" total_received_msgs="64"></stats>
  <interfaces>
    <interface active="true" major_version="0" minor_version="1" name="testinterfaceobject.org">
      <datastream>
        <object reception_timestamp="2019-06-11T13:26:44.218Z">
          <item name="/y">20.0</item>
          <item name="/z">30.0</item>
        </object>
        <object reception_timestamp="2019-06-11T13:26:28.994Z">
          <item name="/x">1.0</item>
          <item name="/z">3.0</item>
        </object>
        <object reception_timestamp="2019-06-11T13:24:03.200Z">
          <item name="/x">0.1</item>
          <item name="/y">0.2</item>
        </object>
      </datastream>
    </interface>
    <interface active="true" major_version="0" minor_version="1" name="testinterface.org">
      <datastream>
        <value reception_timestamp="2019-05-31T09:12:42.789Z">74847848744474874</value>
        <value reception_timestamp="2019-05-31T09:13:29.144Z">78787484848484873</value>
        <value reception_timestamp="2019-05-31T09:13:52.040Z">87364787847847847</value>
      </datastream>
      <datastream>
        <value reception_timestamp="2019-05-31T09:12:42.789Z">2019-05-31T10:12:42.000Z</value>
      </datastream>
      <datastream>
        <value reception_timestamp="2019-05-31T09:12:42.789Z">true</value>
        <value reception_timestamp="2019-05-31T09:13:29.144Z">true</value>
        <value reception_timestamp="2019-05-31T09:13:52.040Z">true</value>
        <value reception_timestamp="2019-05-31T09:25:42.789Z">true</value>
      </datastream>
      <datastream>
        <value reception_timestamp="2019-05-31T09:12:42.789Z">1</value>
        <value reception_timestamp="2019-05-31T09:13:29.144Z">2</value>
        <value reception_timestamp="2019-05-31T09:13:42.789Z">1</value>
        <value reception_timestamp="2019-05-31T09:13:52.040Z">3</value>
        <value reception_timestamp="2019-05-31T09:14:29.144Z">2</value>
        <value reception_timestamp="2019-05-31T09:15:52.040Z">3</value>
      </datastream>
      <datastream>
        <value reception_timestamp="2019-05-31T09:12:42.789Z">0.1</value>
        <value reception_timestamp="2019-05-31T09:13:29.144Z">0.2</value>
        <value reception_timestamp="2019-05-31T09:13:52.040Z">0.3</value>
      </datastream>
      <datastream>
        <value reception_timestamp="2019-05-31T09:12:42.789Z">This is my string</value>
        <value reception_timestamp="2019-05-31T09:13:29.144Z">This is my string2</value>
        <value reception_timestamp="2019-05-31T09:13:52.040Z">This is my string3</value>
      </datastream>
    </interface>
    <interface active="true" major_version="0" minor_version="1" name="com.example.properties">
      <property path="/properties1" reception_timestamp="2020-01-06T00:44:26.921Z">4.2</property>
    </interface>
  </interfaces>
</device>
</devices>
</astarte>
```
# Configiuration
Update MIX configuration to allow accessing the CASSANDRA database tables with page_size options. This reduces the caching of devices data in-memory.
```mixconfig :xandra,
  cassandra_table_page_sizes: [device_table_page_size: 10,
                               individual_datastreams: 100,
                               object_datastreams: 100,
                               individual_properties: 100]

```


