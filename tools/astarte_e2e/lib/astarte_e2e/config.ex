#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
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

defmodule AstarteE2E.Config do
  use Skogsra
  require Logger

  alias Astarte.Core.Device
  alias AstarteE2E.Config.PositiveIntegerOrInfinity
  alias AstarteE2E.Config.AstarteDeviceID
  alias AstarteE2E.Config.ListOfStrings
  alias AstarteE2E.Config.BambooMailAdapter

  @type client_option ::
          {:url, String.t()}
          | {:realm, String.t()}
          | {:jwt, String.t()}
          | {:device_id, Device.encoded_device_id()}
          | {:ignore_ssl_errors, boolean()}
          | {:check_repetitions, integer() | :infinity}

  @type scheduler_option ::
          {:check_interval_s, integer()}
          | {:check_repetitions, integer() | :infinity}
          | {:realm, String.t()}
          | {:device_id, Device.encoded_device_id()}

  @type client_options :: [client_option()]
  @type device_options :: Astarte.Device.device_options()
  @type scheduler_options :: [scheduler_option()]

  @envdoc "Astarte Pairing URL (e.g. https://api.astarte.example.com/pairing)."
  app_env :pairing_url, :astarte_e2e, :pairing_url,
    os_env: "ASTARTE_E2E_PAIRING_URL",
    type: :binary,
    required: true

  @envdoc "An Astarte device ID, which is a valid UUID encoded with standard Astarte device_id encoding (Base64 url encoding, no padding)."
  app_env :device_id, :astarte_e2e, :device_id,
    os_env: "ASTARTE_E2E_DEVICE_ID",
    type: AstarteDeviceID,
    required: true

  @envdoc "Credentials secret."
  app_env :credentials_secret, :astarte_e2e, :credentials_secret,
    os_env: "ASTARTE_E2E_CREDENTIALS_SECRET",
    type: :binary,
    required: true

  @envdoc "Ignore SSL errors. Defaults to false. Changing the value to true is not advised for production environments unless you're aware of what you're doing."
  app_env :ignore_ssl_errors, :astarte_e2e, :ignore_ssl_errors,
    os_env: "ASTARTE_E2E_IGNORE_SSL_ERRORS",
    type: :boolean,
    default: false

  @envdoc "Astarte AppEngine URL (e.g. https://api.astarte.example.com/appengine)."
  app_env :appengine_url, :astarte_e2e, :appengine_url,
    os_env: "ASTARTE_E2E_APPENGINE_URL",
    type: :binary,
    required: true

  @envdoc "Realm name."
  app_env :realm, :astarte_e2e, :realm,
    os_env: "ASTARTE_E2E_REALM",
    type: :binary,
    required: true

  @envdoc "The Astarte JWT employed to access Astarte APIs. The token can be generated with: `$ astartectl utils gen-jwt <service> -k <your-private-key>.pem`."
  app_env :jwt, :astarte_e2e, :jwt,
    os_env: "ASTARTE_E2E_JWT",
    type: :binary,
    required: true

  @envdoc "Time interval between consecutive checks (in seconds)."
  app_env :check_interval_s, :astarte_e2e, :check_interval_s,
    os_env: "ASTARTE_E2E_CHECK_INTERVAL_SECONDS",
    type: :integer,
    default: 60

  @envdoc "The port used to expose AstarteE2E's metrics. Defaults to 4010."
  app_env :port, :astarte_e2e, :port,
    os_env: "ASTARTE_E2E_PORT",
    type: :integer,
    default: 4010

  @envdoc "Overall number of consistency checks repetitions. Defaults to 0, corresponding to infinite checks."
  app_env :check_repetitions, :astarte_e2e, :check_repetitions,
    os_env: "ASTARTE_E2E_CHECK_REPETITIONS",
    type: PositiveIntegerOrInfinity,
    default: :infinity

  @envdoc "The amount of time (in seconds) the websocket client is allowed to wait for an incoming message. Defaults to 10 seconds."
  app_env :client_timeout_s, :astarte_e2e, :client_timeout_s,
    os_env: "ASTARTE_E2E_CLIENT_TIMEOUT_SECONDS",
    type: :pos_integer,
    default: 10

  @envdoc "The maximum number of consecutive timeouts before the websocket client is allowed to crash. Defaults to 10."
  app_env :client_max_timeouts, :astarte_e2e, :client_max_timeouts,
    os_env: "ASTARTE_E2E_CLIENT_MAX_TIMEOUTS",
    type: :pos_integer,
    default: 10

  @envdoc "The comma-separated email recipients."
  app_env :mailer_to_address, :astarte_e2e, :mailer_to_address,
    os_env: "ASTARTE_E2E_MAILER_TO_ADDRESS",
    type: ListOfStrings,
    default: ""

  @envdoc "The notification email sender."
  app_env :mailer_from_address, :astarte_e2e, :mailer_from_address,
    os_env: "ASTARTE_E2E_MAILER_FROM_ADDRESS",
    type: :binary,
    default: ""

  @envdoc """
  The mail service's API key. This env var must be set and valid to use the mail
  service.
  """
  app_env :mail_api_key, :astarte_e2e, :mail_api_key,
    os_env: "ASTARTE_E2E_MAIL_API_KEY",
    type: :binary

  @envdoc """
  The mail domain. This env var must be set and valid to use the mail service.
  """
  app_env :mail_domain, :astarte_e2e, :mail_domain,
    os_env: "ASTARTE_E2E_MAIL_DOMAIN",
    type: :binary

  @envdoc """
  The mail API base URI. This env var must be set and valid to use the mail service.
  """
  app_env :mail_api_base_uri, :astarte_e2e, :mail_api_base_uri,
    os_env: "ASTARTE_E2E_MAIL_API_BASE_URI",
    type: :binary

  @envdoc """
  The mail service. Currently only Mailgun is supported. This env var must be set and
  valid to use the mail service.
  """
  app_env :mail_service, :astarte_e2e, :mail_service,
    os_env: "ASTARTE_E2E_MAIL_SERVICE",
    type: BambooMailAdapter

  @spec websocket_url() :: {:ok, String.t()}
  def websocket_url do
    {:ok, websocket_url!()}
  end

  @spec websocket_url!() :: String.t()
  def websocket_url! do
    url =
      appengine_url!()
      |> generate_websocket_url()

    Path.join([url, "v1", "socket", "websocket"])
  end

  defp generate_websocket_url(appengine_url) do
    cond do
      String.starts_with?(appengine_url, "https://") ->
        String.replace_prefix(appengine_url, "https://", "wss://")

      String.starts_with?(appengine_url, "http://") ->
        String.replace_prefix(appengine_url, "http://", "ws://")

      true ->
        ""
    end
    |> String.trim("/")
  end

  @spec device_opts() :: device_options()
  def device_opts do
    [
      pairing_url: pairing_url!(),
      realm: realm!(),
      device_id: device_id!(),
      credentials_secret: credentials_secret!(),
      interface_provider: standard_interface_provider!(),
      ignore_ssl_errors: ignore_ssl_errors!()
    ]
  end

  @spec client_opts() :: client_options()
  def client_opts do
    [
      url: websocket_url!(),
      realm: realm!(),
      jwt: jwt!(),
      device_id: device_id!(),
      check_repetitions: check_repetitions!(),
      ignore_ssl_errors: ignore_ssl_errors!()
    ]
  end

  @spec scheduler_opts() :: scheduler_options()
  def scheduler_opts do
    [
      check_interval_s: check_interval_s!(),
      check_repetitions: check_repetitions!(),
      realm: realm!(),
      device_id: device_id!()
    ]
  end

  def service_notifier_config do
    with {:mail_adapter, {:ok, mail_adapter}} when not is_nil(mail_adapter) <-
           {:mail_adapter, mail_service()},
         {:ok, base_uri} when not is_nil(base_uri) <- mail_api_base_uri(),
         {:ok, domain} when not is_nil(domain) <- mail_domain(),
         {:ok, api_key} when not is_nil(api_key) <- mail_api_key(),
         {:ok, from} when from != "" <- mailer_from_address(),
         {:ok, to} when to != "" <- mailer_to_address() do
      %{
        chained_adapter: mail_adapter,
        api_key: api_key,
        domain: domain,
        base_uri: base_uri,
        hackney_opts: [
          recv_timeout: :timer.minutes(1)
        ]
      }
    else
      {:mail_adapter, {:ok, nil}} ->
        %{chained_adapter: Bamboo.LocalAdapter}

      _ ->
        Logger.warn("Incomplete mail configuration. The Local Adapter will be used.",
          tag: "local_adapter_fallback"
        )

        %{chained_adapter: Bamboo.LocalAdapter}
    end
  end

  @spec standard_interface_provider() :: {:ok, String.t()}
  def standard_interface_provider do
    {:ok, standard_interface_provider!()}
  end

  @spec standard_interface_provider!() :: String.t()
  def standard_interface_provider! do
    :code.priv_dir(:astarte_e2e)
    |> Path.join("interfaces")
  end
end
