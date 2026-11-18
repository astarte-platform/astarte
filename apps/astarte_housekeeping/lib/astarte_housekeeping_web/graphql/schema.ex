defmodule Astarte.HousekeepingWeb.GraphQL.Schema do
  @moduledoc """
  Astarte Housekeeping Absinthe GraphQL Schema: Realm management and default replication settings.
  """

  use Absinthe.Schema

  import_types(Astarte.HousekeepingWeb.GraphQL.Types.CommonTypes)
  import_types(Astarte.HousekeepingWeb.GraphQL.Types.RealmTypes)

  alias Astarte.Auth.GraphQL.Middleware.AuthorizeFGA
  alias Astarte.HousekeepingWeb.GraphQL.Resolvers.RealmResolver

  query do
    @desc "Health and version check"
    field :health, :string do
      resolve(fn _, _, _ -> {:ok, "ok"} end)
    end

    @desc "List all existing realms in Astarte"
    field :realms, list_of(:string) do
      middleware(AuthorizeFGA, relation: "can_list_realms", target: :cluster)
      resolve(&RealmResolver.list_realms/3)
    end

    @desc "Get configuration for a specific realm"
    field :realm, :realm do
      arg(:realm_name, non_null(:string))

      middleware(AuthorizeFGA, relation: "can_read_realm", target: {:realm, :realm_name})
      resolve(&RealmResolver.get_realm/3)
    end

    @desc "Get default Realm replication settings"
    field :default_replication, :json do
      middleware(AuthorizeFGA, relation: "can_read_cluster_config", target: :cluster)
      resolve(&RealmResolver.get_default_replication/3)
    end
  end

  mutation do
    @desc "Create a new realm"
    field :create_realm, :realm do
      arg(:data, non_null(:json))
      arg(:async_operation, :boolean)

      middleware(AuthorizeFGA, relation: "can_create_realm", target: :cluster)
      resolve(&RealmResolver.create_realm/3)
    end

    @desc "Update an existing realm's configuration"
    field :update_realm, :realm do
      arg(:realm_name, non_null(:string))
      arg(:data, non_null(:json))

      middleware(AuthorizeFGA, relation: "can_update_realm", target: {:realm, :realm_name})
      resolve(&RealmResolver.update_realm/3)
    end

    @desc "Delete a realm from Astarte"
    field :delete_realm, :string do
      arg(:realm_name, non_null(:string))
      arg(:async_operation, :boolean)

      middleware(AuthorizeFGA, relation: "can_delete_realm", target: {:realm, :realm_name})
      resolve(&RealmResolver.delete_realm/3)
    end
  end
end
