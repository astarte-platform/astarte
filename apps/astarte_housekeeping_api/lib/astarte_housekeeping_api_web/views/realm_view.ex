#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.Housekeeping.APIWeb.RealmView do
  use Astarte.Housekeeping.APIWeb, :view
  alias Astarte.Housekeeping.API.Realms.Realm
  alias Astarte.Housekeeping.APIWeb.RealmView

  def render("index.json", %{realms: realms}) do
    %{data: render_many(realms, RealmView, "realm_name_only.json")}
  end

  def render("show.json", %{realm: realm}) do
    render_one(realm, RealmView, "realm.json")
  end

  def render("realm_name_only.json", %{realm: realm}) do
    realm.realm_name
  end

  def render("realm.json", %{realm: %Realm{replication_class: "SimpleStrategy"} = realm}) do
    %{
      data: %{
        realm_name: realm.realm_name,
        jwt_public_key_pem: realm.jwt_public_key_pem,
        replication_class: "SimpleStrategy",
        replication_factor: realm.replication_factor,
        device_registration_limit: realm.device_registration_limit
      }
    }
  end

  def render("realm.json", %{realm: %Realm{replication_class: "NetworkTopologyStrategy"} = realm}) do
    %{
      data: %{
        realm_name: realm.realm_name,
        jwt_public_key_pem: realm.jwt_public_key_pem,
        replication_class: "NetworkTopologyStrategy",
        datacenter_replication_factors: realm.datacenter_replication_factors,
        device_registration_limit: realm.device_registration_limit
      }
    }
  end
end
