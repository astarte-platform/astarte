defmodule Astarte.PairingWeb.GraphQL.Types.AgentTypes do
  use Absinthe.Schema.Notation

  @desc "Response for a successful device registration"
  object :device_registration_response do
    field :credentials_secret, non_null(:string),
      description: "The secret required by the device to obtain credentials"
  end

  @desc "Input for an initial introspection entry"
  input_object :introspection_entry_input do
    @desc "The interface name (e.g., 'org.astarte-platform.genericsensors.Values')"
    field :interface, non_null(:string)

    @desc "The major version of the interface"
    field :major_version, non_null(:integer)

    @desc "The minor version of the interface"
    field :minor_version, non_null(:integer)
  end
end
