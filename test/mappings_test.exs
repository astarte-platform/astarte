#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.DataAccess.MappingsTest do
  use ExUnit.Case
  alias Astarte.Core.Mapping
  alias Astarte.DataAccess.DatabaseTestHelper
  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Mappings

  @simplestreamtest_interface_id <<10, 13, 167, 125, 133, 181, 147, 217, 212, 210, 189, 38, 221,
                                   24, 201, 175>>

  @simplestreamtest_mappings %{
    <<52, 108, 128, 228, 202, 153, 98, 116, 129, 246, 123, 28, 27, 229, 149, 33>> => %Mapping{
      allow_unset: false,
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
    DatabaseTestHelper.seed_data()
  end

  setup_all do
    {:ok, _client} = DatabaseTestHelper.create_test_keyspace()

    on_exit(fn ->
      DatabaseTestHelper.destroy_local_test_keyspace()
    end)

    :ok
  end

  test "fetch interface mappings" do
    {:ok, db_client} = Database.connect("autotestrealm")

    assert Mappings.fetch_interface_mappings_map(db_client, @simplestreamtest_interface_id) ==
             {:ok, @simplestreamtest_mappings}

    # FIXME: this should return {:error, :interface_not_found}
    # missing_interface_id = :crypto.strong_rand_bytes(16)

    # assert Mappings.fetch_interface_mappings_map(db_client, missing_interface_id) ==
    #         {:error, :interface_not_found}
  end
end
