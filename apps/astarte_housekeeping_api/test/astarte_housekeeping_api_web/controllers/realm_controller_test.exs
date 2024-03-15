#
# This file is part of Astarte.
#
# Copyright 2017-2023 SECO Mind Srl
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
  use Astarte.Housekeeping.APIWeb.ConnCase

  alias Astarte.Housekeeping.API.Realms
  alias Astarte.Housekeeping.API.Realms.Realm
  alias Astarte.Housekeeping.API.Config

  @pubkey """
  -----BEGIN PUBLIC KEY-----
  MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAE6ssZpULEsn+wSQdc+DI2+4aj98a1hDKM
  +bxRibfFC0G6SugduGzqIACSdIiLEn4Nubx2jt4tHDpel0BIrYKlCw==
  -----END PUBLIC KEY-----
  """
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

  @create_attrs %{"data" => %{"realm_name" => "testrealm", "jwt_public_key_pem" => @pubkey}}
  @explicit_replication_attrs %{
    "data" => %{
      "realm_name" => "testrealm2",
      "jwt_public_key_pem" => @pubkey,
      "replication_factor" => 3
    }
  }
  @network_topology_attrs %{
    "data" => %{
      "realm_name" => "testrealm3",
      "jwt_public_key_pem" => @pubkey,
      "replication_class" => "NetworkTopologyStrategy",
      "datacenter_replication_factors" => %{
        "boston" => 2,
        "san_francisco" => 1
      }
    }
  }
  @update_attrs %{"data" => %{"jwt_public_key_pem" => @other_pubkey}}
  @invalid_update_attrs %{"data" => %{"jwt_public_key_pem" => @malformed_pubkey}}
  @invalid_name_attrs %{"data" => %{"realm_name" => "0invalid", "jwt_public_key_pem" => @pubkey}}
  @invalid_replication_attrs %{
    "data" => %{
      "realm_name" => "testrealm",
      "jwt_public_key_pem" => @pubkey,
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

  def fixture(:realm) do
    {:ok, realm} = Realms.create_realm(@create_attrs["data"])
    realm
  end

  setup_all do
    Config.put_disable_authentication(true)

    on_exit(fn ->
      Config.reload_disable_authentication()
    end)
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get(conn, realm_path(conn, :index))
    assert json_response(conn, 200) == %{"data" => []}

    conn = post(conn, realm_path(conn, :create), @create_attrs)
    assert response(conn, 201)

    conn = get(conn, realm_path(conn, :index))
    assert json_response(conn, 200) == %{"data" => ["testrealm"]}
  end

  test "creates realm and renders realm when data is valid", %{conn: conn} do
    conn = post(conn, realm_path(conn, :create), @create_attrs)
    assert response(conn, 201)

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

  test "creates realm and renders realm with explicit replication_factor", %{conn: conn} do
    conn = post(conn, realm_path(conn, :create), @explicit_replication_attrs)
    assert response(conn, 201)

    conn = get(conn, realm_path(conn, :show, @explicit_replication_attrs["data"]["realm_name"]))

    assert json_response(conn, 200) == %{
             "data" => %{
               "realm_name" => @explicit_replication_attrs["data"]["realm_name"],
               "jwt_public_key_pem" => @explicit_replication_attrs["data"]["jwt_public_key_pem"],
               "replication_class" => "SimpleStrategy",
               "replication_factor" => @explicit_replication_attrs["data"]["replication_factor"],
               "device_registration_limit" => nil,
               "datastream_maximum_storage_retention" => nil
             }
           }
  end

  test "creates realm and renders realm with network topology", %{conn: conn} do
    conn = post(conn, realm_path(conn, :create), @network_topology_attrs)
    assert response(conn, 201)

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

  test "does not create realm and renders errors when realm_name is invalid", %{conn: conn} do
    conn = post conn, realm_path(conn, :create), @invalid_name_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "does not create realm and renders errors when no public key is provided", %{conn: conn} do
    conn = post(conn, realm_path(conn, :create), @no_pubkey_attrs)
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "does not create realm and renders errors when public key is invalid", %{conn: conn} do
    conn = post(conn, realm_path(conn, :create), @invalid_pubkey_attrs)
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "does not create realm and renders errors when public key is malformed", %{conn: conn} do
    conn = post(conn, realm_path(conn, :create), @malformed_pubkey_attrs)
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "does not create realm and renders errors when replication_factor is invalid", %{
    conn: conn
  } do
    conn = post(conn, realm_path(conn, :create), @invalid_replication_attrs)
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "updates chosen realm when data is valid", %{conn: conn} do
    %Realm{realm_name: realm_name} = realm = fixture(:realm)
    conn = patch(conn, realm_path(conn, :update, realm), @update_attrs)
    assert %{"data" => updated_realm} = json_response(conn, 200)

    assert %{
             "realm_name" => ^realm_name,
             "jwt_public_key_pem" => @other_pubkey
           } = updated_realm
  end

  test "updates chosen realm device registration limit", %{conn: conn} do
    %Realm{realm_name: realm_name} = realm = fixture(:realm)
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
    %Realm{realm_name: realm_name} = realm = fixture(:realm)
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

  test "removes chosen realm device registration limit", %{conn: conn} do
    %Realm{realm_name: realm_name} = realm = fixture(:realm)

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
    %Realm{realm_name: realm_name} = realm = fixture(:realm)

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

  test "does not update chosen realm and renders errors when data is invalid", %{conn: conn} do
    %Realm{realm_name: realm_name} = realm = fixture(:realm)
    conn = patch(conn, realm_path(conn, :update, realm), @invalid_update_attrs)
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "deletes chosen realm", %{conn: conn} do
    realm = fixture(:realm)
    conn = delete(conn, realm_path(conn, :delete, realm))
    assert response(conn, 204)

    conn = get(conn, realm_path(conn, :show, realm))
    assert json_response(conn, 404)
  end
end
