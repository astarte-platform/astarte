#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.DataAccess.Mappings.XandraTest do
  use ExUnit.Case
  alias Astarte.Core.Mapping
  alias Astarte.DataAccess.DatabaseTestHelper
  alias Astarte.DataAccess.Mappings

  @test_realm "autotestrealm"

  @test_interface_id <<83, 208, 155, 48, 103, 205, 220, 243, 222, 30, 40, 112, 234, 210, 31, 19>>

  @test_mapping %{
    <<102, 99, 106, 232, 232, 167, 20, 89, 90, 33, 238, 64, 182, 95, 205, 244>> => %Mapping{
      allow_unset: false,
      database_retention_policy: :no_ttl,
      database_retention_ttl: nil,
      description: "The description.",
      doc: "The doc.",
      endpoint: "/new/interface/value",
      endpoint_id: <<102, 99, 106, 232, 232, 167, 20, 89, 90, 33, 238, 64, 182, 95, 205, 244>>,
      expiry: 0,
      explicit_timestamp: false,
      interface_id: <<83, 208, 155, 48, 103, 205, 220, 243, 222, 30, 40, 112, 234, 210, 31, 19>>,
      path: nil,
      reliability: :unreliable,
      retention: :discard,
      type: nil,
      value_type: :double
    }
  }

  @simplestreamtest_interface_id <<10, 13, 167, 125, 133, 181, 147, 217, 212, 210, 189, 38, 221,
                                   24, 201, 175>>

  @simplestreamtest_mappings %{
    <<52, 108, 128, 228, 202, 153, 98, 116, 129, 246, 123, 28, 27, 229, 149, 33>> => %Mapping{
      allow_unset: false,
      database_retention_policy: :no_ttl,
      database_retention_ttl: nil,
      description: nil,
      doc: nil,
      endpoint: "/foo/%{param}/timestampValue",
      endpoint_id: <<52, 108, 128, 228, 202, 153, 98, 116, 129, 246, 123, 28, 27, 229, 149, 33>>,
      expiry: 0,
      explicit_timestamp: nil,
      interface_id:
        <<10, 13, 167, 125, 133, 181, 147, 217, 212, 210, 189, 38, 221, 24, 201, 175>>,
      path: nil,
      reliability: :unique,
      retention: :discard,
      type: nil,
      value_type: :datetime
    },
    <<57, 7, 212, 29, 91, 202, 50, 157, 158, 81, 76, 234, 42, 84, 169, 154>> => %Mapping{
      allow_unset: false,
      database_retention_policy: :no_ttl,
      database_retention_ttl: nil,
      description: nil,
      doc: nil,
      endpoint: "/foo/%{param}/stringValue",
      endpoint_id: <<57, 7, 212, 29, 91, 202, 50, 157, 158, 81, 76, 234, 42, 84, 169, 154>>,
      expiry: 0,
      explicit_timestamp: nil,
      interface_id:
        <<10, 13, 167, 125, 133, 181, 147, 217, 212, 210, 189, 38, 221, 24, 201, 175>>,
      path: nil,
      reliability: :unique,
      retention: :discard,
      type: nil,
      value_type: :string
    },
    <<117, 1, 14, 27, 25, 158, 238, 252, 221, 53, 210, 84, 176, 226, 9, 36>> => %Mapping{
      allow_unset: false,
      database_retention_policy: :use_ttl,
      database_retention_ttl: 120,
      description: nil,
      doc: nil,
      endpoint: "/%{itemIndex}/value",
      endpoint_id: <<117, 1, 14, 27, 25, 158, 238, 252, 221, 53, 210, 84, 176, 226, 9, 36>>,
      expiry: 0,
      explicit_timestamp: nil,
      interface_id:
        <<10, 13, 167, 125, 133, 181, 147, 217, 212, 210, 189, 38, 221, 24, 201, 175>>,
      path: nil,
      reliability: :unique,
      retention: :discard,
      type: nil,
      value_type: :integer
    },
    <<122, 164, 76, 17, 34, 115, 71, 217, 230, 36, 74, 224, 41, 222, 222, 170>> => %Mapping{
      allow_unset: false,
      database_retention_policy: :no_ttl,
      database_retention_ttl: nil,
      description: nil,
      doc: nil,
      endpoint: "/foo/%{param}/blobValue",
      endpoint_id: <<122, 164, 76, 17, 34, 115, 71, 217, 230, 36, 74, 224, 41, 222, 222, 170>>,
      expiry: 0,
      explicit_timestamp: nil,
      interface_id:
        <<10, 13, 167, 125, 133, 181, 147, 217, 212, 210, 189, 38, 221, 24, 201, 175>>,
      path: nil,
      reliability: :unique,
      retention: :discard,
      type: nil,
      value_type: :binaryblob
    },
    <<239, 249, 87, 207, 3, 223, 222, 237, 151, 132, 168, 112, 142, 61, 140, 185>> => %Mapping{
      allow_unset: false,
      database_retention_policy: :no_ttl,
      database_retention_ttl: nil,
      description: nil,
      doc: nil,
      endpoint: "/foo/%{param}/longValue",
      endpoint_id: <<239, 249, 87, 207, 3, 223, 222, 237, 151, 132, 168, 112, 142, 61, 140, 185>>,
      expiry: 0,
      explicit_timestamp: nil,
      interface_id:
        <<10, 13, 167, 125, 133, 181, 147, 217, 212, 210, 189, 38, 221, 24, 201, 175>>,
      path: nil,
      reliability: :unique,
      retention: :discard,
      type: nil,
      value_type: :longinteger
    }
  }

  setup do
    Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
      DatabaseTestHelper.seed_data(conn)
    end)
  end

  setup_all do
    Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
      DatabaseTestHelper.create_test_keyspace(conn)
    end)

    on_exit(fn ->
      Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
        DatabaseTestHelper.destroy_local_test_keyspace(conn)
      end)
    end)

    :ok
  end

  test "fetch interface mappings" do
    assert Mappings.fetch_interface_mappings_map(
             @test_realm,
             @simplestreamtest_interface_id
           ) ==
             {:ok, @simplestreamtest_mappings}

    assert Mappings.fetch_interface_mappings_map(@test_realm, @test_interface_id,
             include_docs: true
           ) ==
             {:ok, @test_mapping}

    missing_interface_id = :crypto.strong_rand_bytes(16)

    assert Mappings.fetch_interface_mappings_map(@test_realm, missing_interface_id) ==
             {:error, :interface_not_found}
  end
end
