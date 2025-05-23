# Astarte Import

Astarte Import is an easy to use tool that allows to import devices and data into an existing Astarte realm.

```bash
docker run -e CASSANDRA_DB_HOST=127.0.0.1 -e CASSANDRA_DB_PORT=9042 \
 -e REALM=test -e XML_FILE="/files/test.xml" -v $(pwd)/files:/files \
 --net=host astarte/astarte_import
```

Command to run data import:

```bash
mix astarte.import <realm> <xml file>
```

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
```

### Interfaces for import data in Astarte

``` json
{
    "interface_name": "test.individual.parametric.Datastream",
    "version_major": 1,
    "version_minor": 0,
    "type": "datastream",
    "ownership": "device",
    "description": "A device-owned datastream interface with individual aggregation and parametric endpoint.",
    "mappings": [
        {
            "endpoint": "/%{parameter}/boolean",
            "type": "boolean",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/integer",
            "type": "integer",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/double",
            "type": "double",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/longinteger",
            "type": "longinteger",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/string",
            "type": "string",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/binaryblob",
            "type": "binaryblob",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/datetime",
            "type": "datetime",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/doublearray",
            "type": "doublearray",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/integerarray",
            "type": "integerarray",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/booleanarray",
            "type": "booleanarray",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/longintegerarray",
            "type": "longintegerarray",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/stringarray",
            "type": "stringarray",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/datetimearray",
            "type": "datetimearray",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/binaryblobarray",
            "type": "binaryblobarray",
            "explicit_timestamp": true
        }
    ]
}
```
``` json
{
    "interface_name": "test.object.parametric.Datastream",
    "version_major": 1,
    "version_minor": 0,
    "type": "datastream",
    "ownership": "device",
    "aggregation": "object",
    "description": "A device-owned datastream interface with object aggregation and parametric endpoint.",
    "mappings": [
        {
            "endpoint": "/%{parameter}/boolean",
            "type": "boolean",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/integer",
            "type": "integer",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/double",
            "type": "double",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/longinteger",
            "type": "longinteger",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/string",
            "type": "string",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/binaryblob",
            "type": "binaryblob",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/datetime",
            "type": "datetime",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/doublearray",
            "type": "doublearray",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/integerarray",
            "type": "integerarray",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/booleanarray",
            "type": "booleanarray",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/longintegerarray",
            "type": "longintegerarray",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/stringarray",
            "type": "stringarray",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/datetimearray",
            "type": "datetimearray",
            "explicit_timestamp": true
        },
        {
            "endpoint": "/%{parameter}/binaryblobarray",
            "type": "binaryblobarray",
            "explicit_timestamp": true
        }
    ]
}

```

```json
{
    "interface_name": "test.parametric.Properties",
    "version_major": 1,
    "version_minor": 0,
    "type": "properties",
    "ownership": "device",
    "description": "A device-owned properties interface with individual aggregation and parametric endpoint.",
    "mappings": [
        {
            "endpoint": "/%{parameter}/boolean",
            "type": "boolean"
        },
        {
            "endpoint": "/%{parameter}/integer",
            "type": "integer"
        },
        {
            "endpoint": "/%{parameter}/double",
            "type": "double"
        },
        {
            "endpoint": "/%{parameter}/longinteger",
            "type": "longinteger"
        },
        {
            "endpoint": "/%{parameter}/string",
            "type": "string"
        },
        {
            "endpoint": "/%{parameter}/binaryblob",
            "type": "binaryblob"
        },
        {
            "endpoint": "/%{parameter}/datetime",
            "type": "datetime"
        },
        {
            "endpoint": "/%{parameter}/doublearray",
            "type": "doublearray"
        },
        {
            "endpoint": "/%{parameter}/integerarray",
            "type": "integerarray"
        },
        {
            "endpoint": "/%{parameter}/booleanarray",
            "type": "booleanarray"
        },
        {
            "endpoint": "/%{parameter}/longintegerarray",
            "type": "longintegerarray"
        },
        {
            "endpoint": "/%{parameter}/stringarray",
            "type": "stringarray"
        },
        {
            "endpoint": "/%{parameter}/datetimearray",
            "type": "datetimearray"
        },
        {
            "endpoint": "/%{parameter}/binaryblobarray",
            "type": "binaryblobarray"
        }
    ]
}
```
