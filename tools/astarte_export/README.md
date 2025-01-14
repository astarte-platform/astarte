# astarte_export

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

## Environment variables

``` bash
  export export CASSANDRA_DB_HOST="127.0.0.1"
  export CASSANDRA_DB_PORT=9042
  export CASSANDRA_NODES="localhost:9042"
```
## Exporting Data with Astarte

You can export data from an Astarte realm using the following commands.

Export Data for All Devices in a Realm
To export data for all devices in a realm:

```bash
mix astarte.export <REALM> <FILE_XML>
```
- `<REALM>`: The name of the Astarte realm.
- `<FILE_XML>`: The output file path where the exported data will be saved.

Export Data for All Devices in a Realm
To export data for all devices in a realm:

## Export Data for a Specific Device

To export data for a single device in a realm:

```bash
mix astarte.export <REALM> <FILE_XML> <DEVICE_ID>
```

- `<REALM>`: The name of the Astarte realm.
- `<FILE_XML>`: The output file path where the exported data will be saved.
- `<DEVICE_ID>`: The unique identifier of the device (e.g., "ogmcilZpRDeDWwuNfJr0yA").

## Example Commands

Export all devices in the realm example_realm:

``` bash
mix astarte.export example_realm devices_data.xml
```
Export data for a specific device yKA3CMd07kWaDyj6aMP4Dg in the realm example_realm:

``` bash
mix astarte.export example_realm device_data.xml yKA3CMd07kWaDyj6aMP4Dg
```

The exported realm data is captured in xml_format as below.

```xml
<astarte>
  <devices>
    <device device_id="yKA3CMd07kWaDyj6aMP4Dg">
      <protocol pending_empty_cache="false" revision="0"></protocol>
      <registration first_registration="2024-05-30T13:49:57.045Z" secret_bcrypt_hash="$2b$12$bKly9EEKmxfVyDeXjXu1vOebWgr34C8r4IHd9Cd.34Ozm0TWVo1Ve"></registration>
      <credentials cert_aki="a8eaf08a797f0b10bb9e7b5dca027ec2571c5ea6" cert_serial="324725654494785828109237459525026742139358888604" first_credentials_request="2024-05-30T13:49:57.355Z" inhibit_request="false"></credentials>
      <stats last_connection="2024-05-30T13:49:57.561Z" last_disconnection="2024-05-30T13:51:00.038Z" last_seen_ip="198.51.100.89" total_received_bytes="3960" total_received_msgs="64"></stats>
      <interfaces>
        <interface active="true" major_version="0" minor_version="1" name="test.individual.parametric.Datastream">
              <datastream path="/a/boolean">
                <value reception_timestamp="2024-09-09T09:00:00.000Z">true</value>
              </datastream>
              <datastream path="/a/integer">
                <value reception_timestamp="2024-09-09T09:00:00.000Z">123</value>
              </datastream>
              <datastream path="/a/double">
                <value reception_timestamp="2024-09-09T09:00:00.000Z">123.45</value>
              </datastream>
              <datastream path="/a/longinteger">
                <value reception_timestamp="2024-09-09T09:00:00.000Z">123456789012345</value>
              </datastream>
              <datastream path="/a/string">
                <value reception_timestamp="2024-09-09T09:00:00.000Z">example string</value>
              </datastream>
              <datastream path="/a/binaryblob">
                <value reception_timestamp="2024-09-09T09:00:00.000Z">aGVsbG8gd29ybGQ=</value>
              </datastream>
              <datastream path="/a/datetime">
                <value reception_timestamp="2024-09-09T09:00:00.000Z">2024-10-17T13:25:19.130Z</value>
              </datastream>
              <datastream path="/a/doublearray">
                <value reception_timestamp="2024-09-04T11:31:36.956Z">
                  <element>123.45</element>
                  <element>678.90</element>
                </value>
              </datastream>
              <datastream path="/a/integerarray">
                <value reception_timestamp="2024-09-04T11:31:36.956Z">
                  <element>123</element>
                  <element>456</element>
                </value>
              </datastream>
              <datastream path="/a/booleanarray">
                <value reception_timestamp="2024-09-04T11:31:36.956Z">
                  <element>true</element>
                  <element>false</element>
                </value>
              </datastream>
              <datastream path="/a/longintegerarray">
                <value reception_timestamp="2024-09-04T11:31:36.956Z">
                  <element>123456789012345</element>
                  <element>678901234567890</element>
                </value>
              </datastream>
              <datastream path="/a/stringarray">
                <value reception_timestamp="2024-09-04T11:31:36.956Z">
                  <element>string1</element>
                  <element>string2</element>
                </value>
              </datastream>
              <datastream path="/a/datetimearray">
                <value reception_timestamp="2024-09-04T11:31:36.956Z">
                  <element>2024-09-04T11:31:36.956Z</element>
                  <element>2024-09-05T11:31:36.956Z</element>
                </value>
              </datastream>
              <datastream path="/a/binaryblobarray">
                <value reception_timestamp="2024-09-04T11:31:36.956Z">
                  <element>aGVsbG8gd29ybGQ=</element>
                  <element>d29ybGQgaGVsbG8=</element>
                </value>
              </datastream>
            </interface>
        <interface active="true" major_version="0" minor_version="1" name="test.object.parametric.Datastream">
              <datastream path="/a">
                <object reception_timestamp="2024-09-09T09:00:00.000Z">
                  <item name="/boolean">true</item>
                  <item name="/integer">123</item>
                  <item name="/double">123.45</item>
                  <item name="/longinteger">123456789012345</item>
                  <item name="/string">example string</item>
                  <item name="/binaryblob">aGVsbG8gd29ybGQ=</item>
                  <item name="/datetime">2024-10-17T13:25:19.130Z</item>
                  <item name="/doublearray">
                    <element>123.45</element>
                    <element>678.90</element>
                  </item>
                  <item name="/integerarray">
                    <element>123</element>
                    <element>456</element>
                  </item>
                  <item name="/booleanarray">
                    <element>true</element>
                    <element>false</element>
                  </item>
                  <item name="/longintegerarray">
                    <element>123456789012345</element>
                    <element>678901234567890</element>
                  </item>
                  <item name="/stringarray">
                    <element>string1</element>
                    <element>string2</element>
                  </item>
                  <item name="/datetimearray">
                    <element>2024-09-04T11:34:36.956Z</element>
                    <element>2024-09-05T11:34:36.956Z</element>
                  </item>
                  <item name="/binaryblobarray">
                    <element>aGVsbG8gd29ybGQ=</element>
                    <element>d29ybGQgaGVsbG8=</element>
                  </item>
                </object>
              </datastream>
            </interface>
        <interface active="true" major_version="0" minor_version="1" name="test.parametric.Properties">
            <property path="/a/boolean" reception_timestamp="2024-09-09T09:00:00.000Z">true</property>
            <property path="/a/integer" reception_timestamp="2024-09-09T09:00:00.000Z">123</property>
            <property path="/a/double" reception_timestamp="2024-09-09T09:00:00.000Z">123.45</property>
            <property path="/a/longinteger" reception_timestamp="2024-09-09T09:00:00.000Z">123456789012345</property>
            <property path="/a/string" reception_timestamp="2024-09-09T09:00:00.000Z">example string</property>
            <property path="/a/binaryblob" reception_timestamp="2024-09-09T09:00:00.000Z">aGVsbG8gd29ybGQ=</property>
            <property path="/a/datetime" reception_timestamp="2024-09-09T09:00:00.000Z">2024-10-17T13:25:19.130Z</property>
            <property path="/a/doublearray" reception_timestamp="2024-09-04T11:31:36.956Z">
                <element>123.45</element>
                <element>678.90</element>
            </property>
            <property path="/a/integerarray" reception_timestamp="2024-09-04T11:31:36.956Z">
                <element>123</element>
                <element>456</element>
            </property>
            <property path="/a/booleanarray" reception_timestamp="2024-09-04T11:31:36.956Z">
                <element>true</element>
                <element>false</element>
            </property>
            <property path="/a/longintegerarray" reception_timestamp="2024-09-04T11:31:36.956Z">
                <element>123456789012345</element>
                <element>678901234567890</element>
            </property>
            <property path="/a/stringarray" reception_timestamp="2024-09-04T11:31:36.956Z">
                <element>string1</element>
                <element>string2</element>
            </property>
            <property path="/a/datetimearray" reception_timestamp="2024-09-04T11:31:36.956Z">
                <element>2024-09-04T11:31:36.956Z</element>
                <element>2024-09-05T11:31:36.956Z</element>
            </property>
            <property path="/a/binaryblobarray" reception_timestamp="2024-09-04T11:31:36.956Z">
                <element>aGVsbG8gd29ybGQ=</element>
                <element>d29ybGQgaGVsbG8=</element>
            </property>
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


