#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.Housekeeping.APIWeb.RealmControllerTest do
  use Astarte.Housekeeping.APIWeb.ConnCase, async: true
  use Astarte.Housekeeping.APIWeb.AuthCase
  use Mimic

  alias Astarte.DataAccess.Repo
  alias Astarte.Housekeeping.API.Config
  alias Astarte.Housekeeping.API.Realms.Realm
  alias Astarte.Housekeeping.API.Realms.Queries
  alias Astarte.Housekeeping.Engine

  import Astarte.Housekeeping.API.Fixtures.Realm
  import Ecto.Query

  @malformed_pubkey """
  -----BEGIN PUBLIC KEY-----
  MFYwEAYHKoZIzj0CAQYAoDQgAE6ssZpw4aj98a1hDKM
    +bxRibfFC0G6SugduGzqIACSdIiLEn4Nubx2jt4tHDpel0BIrYKlCw==
  -----END PUBLIC KEY-----
  """
  @other_pubkey """
  -----BEGIN PUBLIC KEY-----
  MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEat8cZJ77myME8YQYfVkxOz39Wrq9
  3FYHyYudzQKa11c55Z6ZZaw2H+nUkQl1/jqfHTrqMSiOP4TTf0oTYLWKfg==
  -----END PUBLIC KEY-----
  """
  @local_datacenter from(l in "system.local", select: l.data_center) |> Repo.one!()

  @create_attrs %{"data" => %{"realm_name" => "testrealm", "jwt_public_key_pem" => pubkey()}}
  @explicit_replication_attrs %{
    "data" => %{
      "realm_name" => "testrealm2",
      "jwt_public_key_pem" => pubkey(),
      "replication_factor" => 1
    }
  }
  @network_topology_attrs %{
    "data" => %{
      "realm_name" => "testrealm3",
      "jwt_public_key_pem" => pubkey(),
      "replication_class" => "NetworkTopologyStrategy",
      "datacenter_replication_factors" => %{
        @local_datacenter => 1
      }
    }
  }
  @update_attrs %{"data" => %{"jwt_public_key_pem" => @other_pubkey}}
  @invalid_update_attrs %{"data" => %{"jwt_public_key_pem" => @malformed_pubkey}}
  @invalid_name_attrs %{"data" => %{"realm_name" => "0invalid", "jwt_public_key_pem" => pubkey()}}
  @invalid_replication_attrs %{
    "data" => %{
      "realm_name" => "testrealm",
      "jwt_public_key_pem" => pubkey(),
      "replication_factor" => -3
    }
  }
  @no_pubkey_attrs %{"data" => %{"realm_name" => "valid"}}
  @invalid_pubkey_attrs %{"data" => %{"realm_name" => "valid", "jwt_public_key_pem" => "invalid"}}
  @malformed_pubkey_attrs %{
    "data" => %{
      "realm_name" => "valid",
      "jwt_public_key_pem" => @malformed_pubkey
    }
  }
  @non_existing_realm_name "nonexistingrealm"

  setup_all do
    Config.put_enable_realm_deletion(true)
  end

  describe "index" do
    test "lists all entries on index when no realms exist", %{conn: conn} do
      conn = get(conn, realm_path(conn, :index))
      assert json_response(conn, 200) == %{"data" => []}
    end

    test "lists all entries on index after creating a realm", %{conn: conn} do
      conn = post(conn, realm_path(conn, :create), @create_attrs)
      assert response(conn, 201)

      conn = get(conn, realm_path(conn, :index))
      assert json_response(conn, 200) == %{"data" => ["testrealm"]}
    end
  end

  describe "create realm" do
    test "renders realm when data is valid", %{conn: conn} do
      conn = post(conn, realm_path(conn, :create), @create_attrs)
      assert response(conn, 201)

      # TODO: remove after the create_realm RPC removal
      insert_realm!(@create_attrs)

      conn = get(conn, realm_path(conn, :show, @create_attrs["data"]["realm_name"]))

      assert json_response(conn, 200) == %{
               "data" => %{
                 "realm_name" => @create_attrs["data"]["realm_name"],
                 "jwt_public_key_pem" => @create_attrs["data"]["jwt_public_key_pem"],
                 "replication_class" => "SimpleStrategy",
                 "replication_factor" => 1,
                 "device_registration_limit" => nil,
                 "datastream_maximum_storage_retention" => nil
               }
             }
    end

    test "renders realm with explicit replication_factor", %{conn: conn} do
      conn = post(conn, realm_path(conn, :create), @explicit_replication_attrs)
      assert response(conn, 201)

      # TODO: remove after the create_realm RPC removal
      insert_realm!(@explicit_replication_attrs)

      conn = get(conn, realm_path(conn, :show, @explicit_replication_attrs["data"]["realm_name"]))

      assert json_response(conn, 200) == %{
               "data" => %{
                 "realm_name" => @explicit_replication_attrs["data"]["realm_name"],
                 "jwt_public_key_pem" =>
                   @explicit_replication_attrs["data"]["jwt_public_key_pem"],
                 "replication_class" => "SimpleStrategy",
                 "replication_factor" =>
                   @explicit_replication_attrs["data"]["replication_factor"],
                 "device_registration_limit" => nil,
                 "datastream_maximum_storage_retention" => nil
               }
             }
    end

    test "renders realm with network topology", %{conn: conn} do
      conn = post(conn, realm_path(conn, :create), @network_topology_attrs)
      assert response(conn, 201)

      # TODO: remove after the create_realm RPC removal
      insert_realm!(@network_topology_attrs)

      conn = get(conn, realm_path(conn, :show, @network_topology_attrs["data"]["realm_name"]))

      assert json_response(conn, 200) == %{
               "data" => %{
                 "realm_name" => @network_topology_attrs["data"]["realm_name"],
                 "jwt_public_key_pem" => @network_topology_attrs["data"]["jwt_public_key_pem"],
                 "replication_class" => "NetworkTopologyStrategy",
                 "datacenter_replication_factors" =>
                   @network_topology_attrs["data"]["datacenter_replication_factors"],
                 "device_registration_limit" => nil,
                 "datastream_maximum_storage_retention" => nil
               }
             }
    end

    test "returns a 404 on show non-existing realm", %{conn: conn} do
      conn = get(conn, realm_path(conn, :show, @non_existing_realm_name))

      assert json_response(conn, 404)
    end

    test "renders errors when realm_name is invalid", %{conn: conn} do
      conn = post conn, realm_path(conn, :create), @invalid_name_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders errors when no public key is provided", %{conn: conn} do
      conn = post(conn, realm_path(conn, :create), @no_pubkey_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders errors when public key is invalid", %{conn: conn} do
      conn = post(conn, realm_path(conn, :create), @invalid_pubkey_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders errors when public key is malformed", %{conn: conn} do
      conn = post(conn, realm_path(conn, :create), @malformed_pubkey_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders errors when replication_factor is invalid", %{
      conn: conn
    } do
      conn = post(conn, realm_path(conn, :create), @invalid_replication_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update" do
    test "updates chosen realm when data is valid", %{conn: conn} do
      %Realm{realm_name: realm_name} = realm = realm_fixture()
      conn = patch(conn, realm_path(conn, :update, realm), @update_attrs)
      assert %{"data" => updated_realm} = json_response(conn, 200)

      assert %{
               "realm_name" => ^realm_name,
               "jwt_public_key_pem" => @other_pubkey
             } = updated_realm
    end

    test "updates chosen realm device registration limit", %{conn: conn} do
      %Realm{realm_name: realm_name} = realm = realm_fixture()
      limit = 10

      conn =
        patch(conn, realm_path(conn, :update, realm), %{
          "data" => %{"device_registration_limit" => limit}
        })

      assert %{"data" => updated_realm} = json_response(conn, 200)

      assert %{
               "realm_name" => ^realm_name,
               "device_registration_limit" => ^limit
             } = updated_realm
    end

    test "updates chosen realm maximum storage retention", %{conn: conn} do
      %Realm{realm_name: realm_name} = realm = realm_fixture()
      limit = 10

      conn =
        patch(conn, realm_path(conn, :update, realm), %{
          "data" => %{"datastream_maximum_storage_retention" => limit}
        })

      assert %{"data" => updated_realm} = json_response(conn, 200)

      assert %{
               "realm_name" => ^realm_name,
               "datastream_maximum_storage_retention" => ^limit
             } = updated_realm
    end

    test "renders errors when datastream maximum storage retention is invalid", %{
      conn: conn
    } do
      %Realm{} = realm = realm_fixture()

      conn =
        patch(conn, realm_path(conn, :update, realm), %{
          "data" => %{"datastream_maximum_storage_retention" => -10}
        })

      assert json_response(conn, 422)["errors"] != %{}
    end

    test "removes chosen realm device registration limit", %{conn: conn} do
      %Realm{realm_name: realm_name} = realm = realm_fixture()

      conn =
        patch(conn, realm_path(conn, :update, realm), %{
          "data" => %{"device_registration_limit" => 10}
        })

      assert %{"data" => updated_realm} = json_response(conn, 200)

      assert %{
               "realm_name" => ^realm_name,
               "device_registration_limit" => 10
             } = updated_realm

      conn =
        patch(conn, realm_path(conn, :update, realm), %{
          "data" => %{"device_registration_limit" => nil}
        })

      assert %{"data" => updated_realm} = json_response(conn, 200)

      assert %{
               "realm_name" => ^realm_name,
               "device_registration_limit" => nil
             } = updated_realm
    end

    test "removes chosen realm maximum storage retention", %{conn: conn} do
      %Realm{realm_name: realm_name} = realm = realm_fixture()

      conn =
        patch(conn, realm_path(conn, :update, realm), %{
          "data" => %{"datastream_maximum_storage_retention" => 10}
        })

      assert %{"data" => updated_realm} = json_response(conn, 200)

      assert %{
               "realm_name" => ^realm_name,
               "datastream_maximum_storage_retention" => 10
             } = updated_realm

      conn =
        patch(conn, realm_path(conn, :update, realm), %{
          "data" => %{"datastream_maximum_storage_retention" => nil}
        })

      assert %{"data" => updated_realm} = json_response(conn, 200)

      assert %{
               "realm_name" => ^realm_name,
               "datastream_maximum_storage_retention" => nil
             } = updated_realm
    end

    test "renders errors when data is invalid", %{conn: conn} do
      realm = realm_fixture()
      conn = patch(conn, realm_path(conn, :update, realm), @invalid_update_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete" do
    test "deletes chosen realm", %{conn: conn} do
      realm = realm_fixture()
      conn = delete(conn, realm_path(conn, :delete, realm))
      assert response(conn, 204)

      conn = get(conn, realm_path(conn, :show, realm))
      assert json_response(conn, 404)
    end

    test "returns error when deleting a realm with connected devices", %{conn: conn} do
      Mimic.stub(Queries, :delete_realm, fn _, _ -> {:error, :connected_devices_present} end)

      realm = realm_fixture()
      conn = delete(conn, realm_path(conn, :delete, realm))
      assert response(conn, 422)
    end

    test "returns error when trying to delete a realm while deletion is disabled", %{conn: conn} do
      Mimic.stub(Config, :enable_realm_deletion!, fn -> false end)

      realm = realm_fixture()
      conn = delete(conn, realm_path(conn, :delete, realm))
      assert response(conn, 405)
    end
  end

  # TODO: remove after the create_realm RPC removal
  defp insert_realm!(realm_attrs) do
    realm_attrs =
      realm_attrs["data"] |> Map.new(fn {key, value} -> {String.to_atom(key), value} end)

    {:ok, realm} =
      %Realm{} |> Realm.changeset(realm_attrs) |> Ecto.Changeset.apply_action(:insert)

    replication =
      case realm.replication_class do
        "SimpleStrategy" -> realm.replication_factor
        "NetworkTopologyStrategy" -> realm.datacenter_replication_factors
      end

    Engine.create_realm(
      realm.realm_name,
      realm.jwt_public_key_pem,
      replication,
      realm.device_registration_limit,
      realm.datastream_maximum_storage_retention,
      check_replication?: false
    )
  end
end
