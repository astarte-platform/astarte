# Astarte Import

Astarte Import is an easy to use tool that allows to import devices and data into an existing Astarte realm.

```bash
docker run -e CASSANDRA_DB_HOST=127.0.0.1 -e CASSANDRA_DB_PORT=9042 \
 -e REALM=test -e XML_FILE="/files/test.xml" -v $(pwd)/files:/files \
 --net=host astarte/astarte_import
```

The following example is a valid Astarte Import XML file:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<astarte>
  <devices>
    <device device_id="yKA3CMd07kWaDyj6aMP4Dg">
      <protocol revision="0" pending_empty_cache="false" />
      <registration secret_bcrypt_hash="$2b$12$bKly9EEKmxfVyDeXjXu1vOebWgr34C8r4IHd9Cd.34Ozm0TWVo1Ve" first_registration="2019-05-30T13:49:57.045000Z" />
      <credentials inhibit_request="false" cert_serial="324725654494785828109237459525026742139358888604" cert_aki="a8eaf08a797f0b10bb9e7b5dca027ec2571c5ea6" first_credentials_request="2019-05-30T13:49:57.355000Z" last_credentials_request_ip="198.51.100.1" />
      <stats total_received_msgs="64" total_received_bytes="3960" last_connection="2019-05-30T13:49:57.561000Z" last_disconnection="2019-05-30T13:51:00.038000Z" last_seen_ip="198.51.100.89" />
      <interfaces>
        <interface name="org.astarteplatform.Values" major_version="0" minor_version="1" active="true">
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
```
