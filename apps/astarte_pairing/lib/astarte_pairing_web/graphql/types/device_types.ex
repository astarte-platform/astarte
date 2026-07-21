defmodule Astarte.PairingWeb.GraphQL.Types.DeviceTypes do
  use Absinthe.Schema.Notation

  @desc "Represents a base Device in Astarte Pairing"
  object :device do
    field :id, non_null(:id)
    field :hw_id, non_null(:string)
    field :credentials_secret, :string

    field :info, :device_info
  end

  @desc "Astarte MQTT v1 protocol configuration"
  object :astarte_mqtt_v1 do
    @desc "The MQTT broker URL the device needs to connect to"
    field :broker_url, :string
  end

  @desc "Supported protocols and their configurations for the device"
  object :protocols do
    field :astarte_mqtt_v1, :astarte_mqtt_v1
  end

  @desc "Translation of InfoResponse from OpenApiSpex"
  object :device_info do
    field :version, :string
    field :status, :string

    @desc "Dictionary of supported communication protocols"
    field :protocols, :protocols
  end

  @desc "Translation of AstarteMQTTV1CredentialsResponse"
  object :mqtt_credentials do
    @desc "The generated client certificate in PEM format"
    field :client_crt, :string
  end

  @desc "Translation of AstarteMQTTV1VerifyCredentialsResponse"
  object :mqtt_credentials_verification do
    @desc "true if the credentials are valid, false otherwise"
    field :valid, :boolean

    @desc "the timestamp of the credentials verification"
    field :timestamp, :integer

    @desc "if the certificate is valid, the timestamp after which it will be invalid"
    field :until, :integer

    @desc "the reason the certificate is invalid"
    field :cause, :string

    @desc "additional details on the verification"
    field :details, :string
  end
end
