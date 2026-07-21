defmodule Astarte.PairingWeb.GraphQL.Schema do
  use Absinthe.Schema

  import_types(Astarte.PairingWeb.GraphQL.Types.{DeviceTypes, AgentTypes, FdoTypes})

  # Create an alias to avoid writing the full name of the resolver
  alias Astarte.PairingWeb.GraphQL.Resolvers.DeviceResolver
  alias Astarte.PairingWeb.GraphQL.Resolvers.AgentResolver
  alias Astarte.PairingWeb.GraphQL.Resolvers.FdoResolver
  alias Astarte.PairingWeb.GraphQL.Middleware.AuthorizeFGA

  # QUERIES (Read-only)
  query do
    @desc "Retrieves a device by its hardware ID"
    field :device, :device do
      arg(:hw_id, non_null(:string))

      resolve(&DeviceResolver.get_device/3)
    end

    @desc "List registered owner keys in the realm"
    field :list_owner_keys, :owner_keys_map do
      arg(:key_algorithm, :key_algorithm)

      middleware(AuthorizeFGA,
        relation: "fdo_read",
        target: :realm,
        legacy_method: "GET",
        legacy_path: "fdo/owner_keys"
      )

      resolve(&FdoResolver.list_owner_keys/3)
    end

    @desc "Get details of a specific owner key"
    field :get_owner_key, :owner_key do
      arg(:key_algorithm, non_null(:key_algorithm))
      arg(:key_name, non_null(:string))

      middleware(AuthorizeFGA,
        relation: "fdo_read",
        target: :realm,
        legacy_method: "GET",
        legacy_path_fn: fn args -> "fdo/owner_keys/#{args.key_algorithm}/#{args.key_name}" end
      )

      resolve(&FdoResolver.get_owner_key/3)
    end

    @desc "List owner keys compatible with a given ownership voucher"
    field :owner_keys_for_voucher, :owner_keys_map do
      arg(:ownership_voucher, non_null(:string))

      middleware(AuthorizeFGA,
        relation: "fdo_read",
        target: :realm,
        legacy_method: "POST",
        legacy_path: "fdo/owner_keys_for_voucher"
      )

      resolve(&FdoResolver.owner_keys_for_voucher/3)
    end

    @desc "List registered ownership vouchers in the realm"
    field :list_ownership_vouchers, list_of(:ownership_voucher) do
      middleware(AuthorizeFGA,
        relation: "fdo_read",
        target: :realm,
        legacy_method: "GET",
        legacy_path: "fdo/ownership_vouchers"
      )

      resolve(&FdoResolver.list_ownership_vouchers/3)
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

    @desc "Create or upload an owner key"
    field :create_or_upload_owner_key, :string do
      arg(:action, non_null(:string))
      arg(:key_name, non_null(:string))
      arg(:key_data, :string)
      arg(:key_algorithm, :key_algorithm)

      middleware(AuthorizeFGA,
        relation: "fdo_manage",
        target: :realm,
        legacy_method: "POST",
        legacy_path: "fdo/owner_keys"
      )

      resolve(&FdoResolver.create_or_upload_owner_key/3)
    end

    @desc "Register a device ownership voucher"
    field :register_ownership_voucher, :register_ownership_voucher_response do
      arg(:ownership_voucher, non_null(:string))
      arg(:key_name, non_null(:string))
      arg(:key_algorithm, non_null(:key_algorithm))
      arg(:replacement_public_key, :string)
      arg(:replacement_guid, :string)
      arg(:replacement_rendezvous_info, :string)

      middleware(AuthorizeFGA,
        relation: "fdo_manage",
        target: :realm,
        legacy_method: "POST",
        legacy_path: "fdo/ownership_vouchers"
      )

      resolve(&FdoResolver.register_ownership_voucher/3)
    end
  end
end
