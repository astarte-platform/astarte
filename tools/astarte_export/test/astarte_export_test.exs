defmodule Astarte.ExportTest do
  use ExUnit.Case
  alias Astarte.Export
  alias Astarte.Export.XMLGenerate
  alias Astarte.Export.FetchData
  alias Astarte.DatabaseTestdata
  @realm "test"

  @expected_xml """
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

  test "export realm data to xmlfile" do
    DatabaseTestdata.initialize_database()
    assert {:ok, :export_completed} == Export.export_realm_data(@realm, "test.xml")
    file = Path.expand("test.xml") |> Path.absname()
    assert @expected_xml == File.read!(file)
  end

  test "export realm data to xmlfile in a absolute path " do
    file = File.cwd!() <> "/test.xml"
    assert {:ok, :export_completed} == Export.export_realm_data(@realm, file)
    assert @expected_xml == File.read!(file)
  end

  test "test to export xml data " do
    {:ok, stdio} = read_stdio_output_on_port()
    {:ok, state} = XMLGenerate.xml_write_default_header(:standard_error)
    assert [] == state

    {:ok, state} = XMLGenerate.xml_write_start_tag(:standard_error, {"astarte", []}, state)
    assert ["astarte"] == state

    {:ok, state} = XMLGenerate.xml_write_start_tag(:standard_error, {"devices", []}, state)
    assert ["devices", "astarte"] == state

    {:ok, conn} = FetchData.db_connection_identifier()

    {:more_data, [device_data], _} = FetchData.fetch_device_data(conn, @realm, [])

    mapped_device_data = FetchData.process_device_data(device_data)

    attributes = mapped_device_data.device

    {:ok, state} = XMLGenerate.xml_write_start_tag(:standard_error, {"device", attributes}, state)
    assert ["device", "devices", "astarte"] == state

    {:ok, state} = Export.construct_device_xml_tags(mapped_device_data, :standard_error, state)
    assert ["device", "devices", "astarte"] == state

    {:ok, state} = Export.process_interfaces(conn, @realm, device_data, :standard_error, state)
    assert ["device", "devices", "astarte"] == state

    {:ok, state} = XMLGenerate.xml_write_end_tag(:standard_error, state)
    assert ["devices", "astarte"] == state

    {:ok, state} = XMLGenerate.xml_write_end_tag(:standard_error, state)
    assert ["astarte"] == state

    {:ok, state} = XMLGenerate.xml_write_end_tag(:standard_error, state)
    assert [] == state

    assert StringIO.flush(stdio) == @expected_xml
  end

  def read_stdio_output_on_port() do
    Process.unregister(:standard_error)
    {:ok, dev} = StringIO.open("")
    Process.register(dev, :standard_error)
    {:ok, dev}
  end
end
