defmodule Astarte.PairingWeb.GraphQL.Schema do
  use Absinthe.Schema

  import_types(Astarte.PairingWeb.GraphQL.Types.{DeviceTypes, AgentTypes})

  # Create an alias to avoid writing the full name of the resolver
  alias Astarte.PairingWeb.GraphQL.Resolvers.DeviceResolver
  alias Astarte.PairingWeb.GraphQL.Resolvers.AgentResolver
  alias Astarte.PairingWeb.GraphQL.Middleware.AuthorizeFGA

  # QUERIES (Read-only)
  query do
    @desc "Retrieves a device by its hardware ID"
    field :device, :device do
      arg(:hw_id, non_null(:string))

      resolve(&DeviceResolver.get_device/3)
    end
  end

  # MUTATIONS (Write / Generation)
  mutation do
    @desc "Register a device, obtaining its credentials secret. Requires Agent permissions."
    field :register_device, :device_registration_response do
      arg(:hw_id, non_null(:string), description: "The Device ID to register")

      @desc "Optional initial introspection for the device"
      arg(:initial_introspection, list_of(non_null(:introspection_entry_input)))

      middleware(AuthorizeFGA,
        relation: "device_register",
        target: :realm,
        legacy_method: "POST",
        legacy_path: "agent/devices"
      )

      resolve(&AgentResolver.register_device/3)
    end

    @desc "Unregister a device. Requires Agent permissions."
    field :unregister_device, :string do
      arg(:hw_id, non_null(:string), description: "The Device ID to unregister")

      middleware(AuthorizeFGA,
        relation: "can_unregister",
        target: :device,
        legacy_method: "DELETE",
        legacy_path_fn: fn args -> "agent/devices/#{args.hw_id}" end
      )

      resolve(&AgentResolver.unregister_device/3)
    end

    @desc "Generates an MQTT v1 client certificate from a Certificate Signing Request (CSR). Requires device credentials secret."
    field :obtain_mqtt_credentials, :mqtt_credentials do
      arg(:hw_id, non_null(:string), description: "The hardware ID of the device")
      arg(:csr, non_null(:string), description: "The Certificate Signing Request in PEM format")

      middleware(AuthorizeFGA,
        relation: "can_obtain_credentials",
        target: :device,
        legacy_method: "POST",
        legacy_path_fn: fn args ->
          "devices/#{args.hw_id}/protocols/astarte_mqtt_v1/credentials"
        end
      )

      resolve(&DeviceResolver.obtain_credentials/3)
    end

    @desc "Verifies the validity of an MQTT v1 client certificate. Requires device credentials secret."
    field :verify_mqtt_credentials, :mqtt_credentials_verification do
      arg(:hw_id, non_null(:string), description: "The hardware ID of the device")
      arg(:client_crt, non_null(:string), description: "The client certificate in PEM format")

      middleware(AuthorizeFGA,
        relation: "can_verify_credentials",
        target: :device,
        legacy_method: "POST",
        legacy_path_fn: fn args ->
          "devices/#{args.hw_id}/protocols/astarte_mqtt_v1/credentials/verify"
        end
      )

      resolve(&DeviceResolver.verify_credentials/3)
    end
  end
end
