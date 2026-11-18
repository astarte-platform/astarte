defmodule Astarte.HousekeepingWeb.GraphQL.Types.RealmTypes do
  @moduledoc false
  use Absinthe.Schema.Notation

  @desc "Astarte Realm object representation"
  object :realm do
    field :realm_name, non_null(:string)
    field :jwt_public_key_pem, :string
    field :jwt_public_key, :string, resolve: fn realm, _, _ -> {:ok, realm.jwt_public_key_pem} end
    field :replication_factor, :integer
    field :replication_class, :string
    field :datacenter_replication_factors, :json

    field :device_registration_limit, :integer,
      resolve: fn realm, _, _ ->
        case realm.device_registration_limit do
          :unset -> {:ok, nil}
          val -> {:ok, val}
        end
      end

    field :datastream_maximum_storage_retention, :integer,
      resolve: fn realm, _, _ ->
        case realm.datastream_maximum_storage_retention do
          :unset -> {:ok, nil}
          val -> {:ok, val}
        end
      end
  end
end
