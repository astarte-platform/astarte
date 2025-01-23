# Copyright 2019 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

defmodule Astarte.Export.FetchDataDBTest do
  use ExUnit.Case
  alias Astarte.Export.FetchData
  alias Astarte.Export.FetchData.Queries
  alias Astarte.Core.Device

  @realm "test"
  @device_id_expected "yKA3CMd07kWaDyj6aMP4Dg"
  @individual_datastream_interface "org.individualdatastreams.values"
  @major_version 0
  test "test to extract device from database using query_handler and verify device_id " do
    {:ok, conn} = Queries.get_connection()
    {:ok, result} = Queries.stream_devices(conn, @realm, [])
    [device_record | _] = Enum.to_list(result)
    device_id = Device.encode_device_id(device_record.device_id)
    assert device_id == @device_id_expected
  end

  test "test to extract an interface information from interfaces tables for test realm" do
    interface_details = %Astarte.Core.InterfaceDescriptor{
      aggregation: :individual,
      automaton:
        {%{
           {0, "testinstall1"} => 1,
           {0, "testinstall2"} => 2,
           {0, "testinstall3"} => 3,
           {0, "testinstall4"} => 4,
           {0, "testinstall5"} => 5
         },
         %{
           1 => <<138, 232, 32, 4, 6, 189, 230, 9, 37, 174, 18, 246, 100, 208, 59, 61>>,
           2 => <<239, 214, 216, 27, 149, 244, 197, 154, 249, 139, 4, 124, 203, 209, 129, 104>>,
           3 => <<246, 193, 132, 180, 190, 183, 60, 188, 205, 97, 232, 109, 186, 77, 12, 104>>,
           4 => <<172, 167, 229, 205, 125, 90, 98, 1, 108, 196, 77, 90, 237, 255, 243, 181>>,
           5 => <<139, 126, 229, 60, 227, 249, 244, 249, 43, 11, 16, 50, 55, 119, 228, 200>>
         }},
      interface_id: <<215, 150, 135, 110, 91, 114, 158, 159, 125, 93, 40, 196, 80, 40, 44, 172>>,
      major_version: 0,
      minor_version: 1,
      name: "org.individualdatastreams.values",
      ownership: :device,
      storage: "individual_datastreams",
      storage_type: :multi_interface_individual_datastream_dbtable,
      type: :datastream
    }

    {:ok, conn} = Queries.get_connection()

    assert {:ok, interface_details} ==
             Queries.fetch_interface_descriptor(
               conn,
               @realm,
               @individual_datastream_interface,
               @major_version,
               []
             )
  end

  test " test to fetch interface mappings from endpoint table" do
    interface_id = <<215, 150, 135, 110, 91, 114, 158, 159, 125, 93, 40, 196, 80, 40, 44, 172>>

    interface_mappings = [
      %Astarte.Core.Mapping{
        allow_unset: false,
        database_retention_policy: :no_ttl,
        database_retention_ttl: nil,
        description: nil,
        doc: nil,
        endpoint: "/testinstall3",
        endpoint_id:
          <<246, 193, 132, 180, 190, 183, 60, 188, 205, 97, 232, 109, 186, 77, 12, 104>>,
        expiry: 0,
        explicit_timestamp: false,
        interface_id:
          <<215, 150, 135, 110, 91, 114, 158, 159, 125, 93, 40, 196, 80, 40, 44, 172>>,
        path: nil,
        reliability: :unreliable,
        retention: :discard,
        type: nil,
        value_type: :boolean
      },
      %Astarte.Core.Mapping{
        allow_unset: false,
        database_retention_policy: :no_ttl,
        database_retention_ttl: nil,
        description: nil,
        doc: nil,
        endpoint: "/testinstall4",
        endpoint_id: <<172, 167, 229, 205, 125, 90, 98, 1, 108, 196, 77, 90, 237, 255, 243, 181>>,
        expiry: 0,
        explicit_timestamp: false,
        interface_id:
          <<215, 150, 135, 110, 91, 114, 158, 159, 125, 93, 40, 196, 80, 40, 44, 172>>,
        path: nil,
        reliability: :unreliable,
        retention: :discard,
        type: nil,
        value_type: :string
      },
      %Astarte.Core.Mapping{
        allow_unset: false,
        database_retention_policy: :no_ttl,
        database_retention_ttl: nil,
        description: nil,
        doc: nil,
        endpoint: "/testinstall2",
        endpoint_id:
          <<239, 214, 216, 27, 149, 244, 197, 154, 249, 139, 4, 124, 203, 209, 129, 104>>,
        expiry: 0,
        explicit_timestamp: false,
        interface_id:
          <<215, 150, 135, 110, 91, 114, 158, 159, 125, 93, 40, 196, 80, 40, 44, 172>>,
        path: nil,
        reliability: :unreliable,
        retention: :discard,
        type: nil,
        value_type: :integer
      },
      %Astarte.Core.Mapping{
        allow_unset: false,
        database_retention_policy: :no_ttl,
        database_retention_ttl: nil,
        description: nil,
        doc: nil,
        endpoint: "/testinstall1",
        endpoint_id: <<138, 232, 32, 4, 6, 189, 230, 9, 37, 174, 18, 246, 100, 208, 59, 61>>,
        expiry: 0,
        explicit_timestamp: false,
        interface_id:
          <<215, 150, 135, 110, 91, 114, 158, 159, 125, 93, 40, 196, 80, 40, 44, 172>>,
        path: nil,
        reliability: :unreliable,
        retention: :discard,
        type: nil,
        value_type: :double
      },
      %Astarte.Core.Mapping{
        allow_unset: false,
        database_retention_policy: :no_ttl,
        database_retention_ttl: nil,
        description: nil,
        doc: nil,
        endpoint: "/testinstall5",
        endpoint_id: <<139, 126, 229, 60, 227, 249, 244, 249, 43, 11, 16, 50, 55, 119, 228, 200>>,
        expiry: 0,
        explicit_timestamp: false,
        interface_id:
          <<215, 150, 135, 110, 91, 114, 158, 159, 125, 93, 40, 196, 80, 40, 44, 172>>,
        path: nil,
        reliability: :unreliable,
        retention: :discard,
        type: nil,
        value_type: :longinteger
      }
    ]

    {:ok, conn} = Queries.get_connection()

    assert {:ok, interface_mappings} ==
             Queries.fetch_interface_mappings(conn, @realm, interface_id, [])
  end
end
