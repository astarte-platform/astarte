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
#

# TODO: Copied from astarte_data_access PR #71, see: https://github.com/astarte-platform/astarte_data_access/pull/71
# use `astarte_data_access` when it will be merged
defmodule Astarte.RealmManagement.Astarte.Realm do
  use TypedEctoSchema

  alias Astarte.RealmManagement.Config

  @primary_key {:realm_name, :string, autogenerate: false}
  typed_schema "realms" do
    field :device_registration_limit, :integer
  end

  @spec keyspace_name(String.t()) :: String.t()
  def keyspace_name(realm_name) do
    realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())
  end

  # TODO: copy from Astarte.Core @master. Remove once available in release 1.2
  @spec realm_name_to_keyspace_name(nonempty_binary(), binary()) :: nonempty_binary()
  defp realm_name_to_keyspace_name(realm_name, astarte_instance_id)
       when is_binary(realm_name) do
    instance_and_realm = astarte_instance_id <> realm_name

    case String.length(instance_and_realm) do
      len when len >= 48 -> Base.url_encode64(instance_and_realm, padding: false)
      _ -> instance_and_realm
    end
    |> String.replace("-", "")
    |> String.replace("_", "")
    |> String.slice(0..47)
    |> String.downcase()
  end
end
