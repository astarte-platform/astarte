#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.DataAccess.Realms.Realm do
  @moduledoc """
  This module defines the Ecto schema for the `realms` table, which stores information about realms in Astarte Data Access.
  """
  use TypedEctoSchema

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Realm
  alias Astarte.DataAccess.Config

  @primary_key {:realm_name, :string, autogenerate: false}
  typed_schema "realms" do
    field :device_registration_limit, :integer
  end

  @spec keyspace_name(String.t()) :: String.t()

  def keyspace_name(realm_name) do
    case Realm.valid_name?(realm_name) do
      true -> CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())
      _ -> raise ArgumentError, "invalid realm name"
    end
  end

  def astarte_keyspace_name do
    CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())
  end
end
