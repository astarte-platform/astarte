defmodule Astarte.HousekeepingWeb.ApiSpec.Schemas.Realm do
  @moduledoc false

  defmodule Realm do
    @moduledoc false

    require OpenApiSpex

    alias OpenApiSpex.Schema

    @public_key_example """
    -----BEGIN PUBLIC KEY-----
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsj7/Ci5Nx+ApLNW7+DyE
    eTzQ68KEJT/gPW73Kpa2uyvxDwY669z/rP4hMj16wv4Ku3bI6C1ZIqT5SVuF8pDo
    1Y1SF0GRIeslupm9KV1aFqIu1/srLz18LQHucQYUSa99PStFUJY2V83wneaeAArY
    4VKDuQYtRZOd2VeD5Cbn602ksLLWCQc9HfL3VUHXTw6DuthnMMJARcVem8RAMScm
    htGi6YRPFzvHtkb1WQCNGjw5gAmHX5/37ouwbBdnXOa9deiFv+1UIdcCVwMTyP/4
    f9jgaxW4oQV85enS/OJrrC9jU11agRc4bDv1h4s2t+ETWb4llTVk3HMIHbC3EvKJ
    VwIDAQAB
    -----END PUBLIC KEY-----
    """

    OpenApiSpex.schema(%{
      title: "Realm",
      type: :object,
      required: [:realm_name, :jwt_public_key_pem],
      properties: %{
        realm_name: %Schema{type: :string, example: "myrealm"},
        jwt_public_key_pem: %Schema{
          type: :string,
          example: @public_key_example,
          description: "PEM-encoded public key of the realm."
        },
        replication_class: %Schema{
          type: :string,
          example: "SimpleStrategy",
          description: "Replication Class of the keyspace that holds the realm's data."
        },
        replication_factor: %Schema{
          type: :integer,
          example: 2,
          description:
            "Replication factor of the keyspace that holds the realm's data (only if replication_class is \"SimpleStrategy\")."
        },
        datacenter_replication_factor: %Schema{
          type: :object,
          additionalProperties: %Schema{type: :integer},
          example: %{
            datacenter_1: 1,
            datacenter_2: 3
          },
          description:
            "Datacenter replication factor of the keyspace that holds the realm's data (only if replication_class is \"NetworkTopologyStrategy\")."
        },
        device_registration_limit: %Schema{
          type: :integer,
          minimum: 0,
          example: 100,
          description:
            "Optional upper bound to the number of devices that can be registered in the realm."
        },
        datastream_maximum_storage_retention: %Schema{
          type: :integer,
          minimum: 1,
          example: 100,
          description:
            "Optional upper bound to the retention period of all datastreams in the realm, in seconds."
        }
      },
      example: %{
        realm_name: "myrealm",
        jwt_public_key_pem: @public_key_example,
        replication_class: "SimpleStrategy",
        replication_factor: 2
      }
    })
  end

  defmodule RealmPatch do
    @moduledoc false

    require OpenApiSpex

    alias OpenApiSpex.Schema

    @public_key_example """
    -----BEGIN PUBLIC KEY-----
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsj7/Ci5Nx+ApLNW7+DyE
    eTzQ68KEJT/gPW73Kpa2uyvxDwY669z/rP4hMj16wv4Ku3bI6C1ZIqT5SVuF8pDo
    1Y1SF0GRIeslupm9KV1aFqIu1/srLz18LQHucQYUSa99PStFUJY2V83wneaeAArY
    4VKDuQYtRZOd2VeD5Cbn602ksLLWCQc9HfL3VUHXTw6DuthnMMJARcVem8RAMScm
    htGi6YRPFzvHtkb1WQCNGjw5gAmHX5/37ouwbBdnXOa9deiFv+1UIdcCVwMTyP/4
    f9jgaxW4oQV85enS/OJrrC9jU11agRc4bDv1h4s2t+ETWb4llTVk3HMIHbC3EvKJ
    VwIDAQAB
    -----END PUBLIC KEY-----
    """

    OpenApiSpex.schema(%{
      title: "RealmPatch",
      type: :object,
      properties: %{
        jwt_public_key_pem: %Schema{
          type: :string,
          example: @public_key_example,
          description: "PEM-encoded public key of the realm."
        },
        device_registration_limit: %Schema{
          type: :integer,
          minimum: 0,
          example: 100,
          description:
            "Optional upper bound to the number of devices that can be registered in the realm."
        },
        datastream_maximum_storage_retention: %Schema{
          type: :integer,
          minimum: 1,
          example: 100,
          description:
            "Optional upper bound to the retention period of all datastreams in the realm, in seconds."
        }
      },
      example: %{
        jwt_public_key_pem: @public_key_example
      }
    })
  end
end
