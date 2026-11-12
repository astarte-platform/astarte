#
# This file is part of Astarte.
#
# Copyright 2026 Clea Srl
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

defmodule Astarte.RealmManagementWeb.GraphQL.Schema do
  @moduledoc """
  Astarte Realm Management's Absinthe GraphQL schema.
  """
  use Absinthe.Schema

  import_types(Astarte.RealmManagementWeb.GraphQL.Types.CommonTypes)

  alias Astarte.Auth.GraphQL.Middleware.AuthorizeFGA
  alias Astarte.RealmManagementWeb.GraphQL.Middleware.HandleErrors
  alias Astarte.RealmManagementWeb.GraphQL.Resolvers.ConfigResolver
  alias Astarte.RealmManagementWeb.GraphQL.Resolvers.DeviceResolver
  alias Astarte.RealmManagementWeb.GraphQL.Resolvers.InterfaceResolver
  alias Astarte.RealmManagementWeb.GraphQL.Resolvers.TriggerResolver

  # Every query and mutation leaves turning its errors into GraphQL errors to
  # HandleErrors.
  @impl Absinthe.Schema
  def middleware(middleware, _field, %{identifier: identifier})
      when identifier in [:query, :mutation],
      do: middleware ++ [HandleErrors]

  def middleware(middleware, _field, _object), do: middleware

  query do
    @desc "A placeholder query to verify GraphQL is running."
    field :health, :string do
      resolve(fn _, _, _ ->
        {:ok, "Realm Management GraphQL API is running"}
      end)
    end

    # INTERFACES
    @desc "Get a list of all installed interfaces"
    field :interfaces, list_of(:json) do
      arg(:detailed, :boolean,
        description: "If true, returns interface definitions instead of just names"
      )

      middleware(AuthorizeFGA, relation: "can_list_interfaces", target: :realm)
      resolve(&InterfaceResolver.list_interfaces/3)
    end

    @desc "Get a specific interface by name and major version"
    field :interface, :json do
      arg(:interface_name, non_null(:string))
      arg(:major_version, non_null(:integer))

      middleware(AuthorizeFGA, relation: "can_read", target: {:interface, :interface_name})
      resolve(&InterfaceResolver.get_interface/3)
    end

    @desc "Get all major versions of a specific interface"
    field :interface_versions, list_of(:integer) do
      arg(:interface_name, non_null(:string))

      middleware(AuthorizeFGA, relation: "can_read", target: {:interface, :interface_name})
      resolve(&InterfaceResolver.get_interface_versions/3)
    end

    # CONFIG
    @desc "Get the auth configuration of the realm"
    field :auth_config, :json do
      middleware(AuthorizeFGA, relation: "can_read_realm_config", target: :realm)
      resolve(&ConfigResolver.get_auth_config/3)
    end

    @desc "Get the maximum number of devices that can be registered in the realm"
    field :device_registration_limit, :integer do
      middleware(AuthorizeFGA, relation: "can_read_realm_config", target: :realm)
      resolve(&ConfigResolver.get_device_registration_limit/3)
    end

    @desc "Get the maximum storage retention for datastreams in seconds"
    field :datastream_maximum_storage_retention, :integer do
      middleware(AuthorizeFGA, relation: "can_read_realm_config", target: :realm)
      resolve(&ConfigResolver.get_datastream_maximum_storage_retention/3)
    end

    # TRIGGERS
    @desc "Get a list of all installed triggers"
    field :triggers, list_of(:string) do
      middleware(AuthorizeFGA, relation: "can_list_triggers", target: :realm)
      resolve(&TriggerResolver.list_triggers/3)
    end

    @desc "Get trigger configuration"
    field :trigger, :json do
      arg(:trigger_name, non_null(:string))

      middleware(AuthorizeFGA, relation: "can_read", target: {:trigger, :trigger_name})
      resolve(&TriggerResolver.get_trigger/3)
    end

    # TRIGGER POLICIES
    @desc "Get a list of all installed trigger delivery policies"
    field :policies, list_of(:string) do
      middleware(AuthorizeFGA, relation: "can_list_trigger_policies", target: :realm)
      resolve(&TriggerResolver.list_policies/3)
    end

    @desc "Get the trigger delivery policy configuration"
    field :policy, :json do
      arg(:policy_name, non_null(:string))

      middleware(AuthorizeFGA, relation: "can_read", target: {:trigger_policy, :policy_name})
      resolve(&TriggerResolver.get_policy/3)
    end
  end

  mutation do
    # INTERFACES
    @desc "Install a new interface to the realm"
    field :install_interface, :string do
      arg(:data, non_null(:json))
      arg(:async_operation, :boolean)

      middleware(AuthorizeFGA, relation: "can_install_interface", target: :realm)
      resolve(&InterfaceResolver.install_interface/3)
    end

    @desc "Updates an existing interface to a new minor release"
    field :update_interface, :string do
      arg(:interface_name, non_null(:string))
      arg(:major_version, non_null(:integer))
      arg(:data, non_null(:json))
      arg(:async_operation, :boolean)

      middleware(AuthorizeFGA, relation: "can_update", target: {:interface, :interface_name})
      resolve(&InterfaceResolver.update_interface/3)
    end

    @desc "Delete a draft interface (major version 0)"
    field :delete_interface_draft, :string do
      arg(:interface_name, non_null(:string))
      arg(:major_version, non_null(:integer))
      arg(:async_operation, :boolean)

      middleware(AuthorizeFGA, relation: "can_delete", target: {:interface, :interface_name})
      resolve(&InterfaceResolver.delete_interface_draft/3)
    end

    # CONFIG
    @desc "Install a new auth configuration for the realm"
    field :update_auth_config, :string do
      arg(:data, non_null(:json))

      middleware(AuthorizeFGA, relation: "can_update_realm_config", target: :realm)
      resolve(&ConfigResolver.update_auth_config/3)
    end

    # TRIGGERS
    @desc "Install a new trigger configuration"
    field :install_trigger, :json do
      arg(:data, non_null(:json))

      middleware(AuthorizeFGA, relation: "can_create_trigger", target: :realm)
      resolve(&TriggerResolver.install_trigger/3)
    end

    @desc "Delete a trigger"
    field :delete_trigger, :string do
      arg(:trigger_name, non_null(:string))

      middleware(AuthorizeFGA, relation: "can_delete", target: {:trigger, :trigger_name})
      resolve(&TriggerResolver.delete_trigger/3)
    end

    # TRIGGER POLICIES
    @desc "Install a new trigger delivery policy configuration"
    field :install_policy, :json do
      arg(:data, non_null(:json))

      middleware(AuthorizeFGA, relation: "can_create_trigger_policy", target: :realm)
      resolve(&TriggerResolver.install_policy/3)
    end

    @desc "Delete a trigger delivery policy"
    field :delete_policy, :string do
      arg(:policy_name, non_null(:string))
      arg(:async_operation, :boolean)

      middleware(AuthorizeFGA, relation: "can_delete", target: {:trigger_policy, :policy_name})
      resolve(&TriggerResolver.delete_policy/3)
    end

    # DEVICES
    @desc "Delete a device"
    field :delete_device, :string do
      arg(:device_id, non_null(:string))

      middleware(AuthorizeFGA, relation: "can_delete", target: {:device, :device_id})
      resolve(&DeviceResolver.delete_device/3)
    end
  end
end
