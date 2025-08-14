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

  alias AstarteE2E.Config.PositiveIntegerOrInfinity
  alias AstarteE2E.Config.ListOfStrings
  alias AstarteE2E.Config.BambooMailAdapter
  alias AstarteE2E.Config.NormalizedMailAddress

  @type client_option ::
          {:url, String.t()}
          | {:realm, String.t()}
          | {:jwt, String.t()}
          | {:ignore_ssl_errors, boolean()}
          | {:check_repetitions, integer() | :infinity}

  @type scheduler_option ::
          {:check_interval_s, integer()}
          | {:check_repetitions, integer() | :infinity}
          | {:realm, String.t()}

  @type notifier_option ::
          {:mail_subject, String.t()}

  @type client_options :: [client_option()]
  @type device_options :: Astarte.Device.device_options()
  @type scheduler_options :: [scheduler_option()]
  @type notifier_options :: [notifier_option()]

  @envdoc "Astarte Pairing URL (e.g. https://api.astarte.example.com/pairing)."
  app_env :pairing_url, :astarte_e2e, :pairing_url,
    os_env: "E2E_PAIRING_URL",
    type: :binary,
    required: true

  @envdoc "Ignore SSL errors. Defaults to false. Changing the value to true is not advised for production environments unless you're aware of what you're doing."
  app_env :ignore_ssl_errors, :astarte_e2e, :ignore_ssl_errors,
    os_env: "E2E_IGNORE_SSL_ERRORS",
    type: :boolean,
    default: false

  @envdoc "Astarte AppEngine URL (e.g. https://api.astarte.example.com/appengine)."
  app_env :appengine_url, :astarte_e2e, :appengine_url,
    os_env: "E2E_APPENGINE_URL",
    type: :binary,
    required: true

  @envdoc "Astarte RealmManagement URL (e.g. https://api.astarte.example.com/realmmanagement)."
  app_env :realm_management_url, :astarte_e2e, :realm_management_url,
    os_env: "E2E_REALM_MANAGEMENT_URL",
    type: :binary,
    required: true

  @envdoc "Realm name."
  app_env :realm, :astarte_e2e, :realm,
    os_env: "E2E_REALM",
    type: :binary,
    required: true

  @envdoc "The Astarte JWT employed to access Astarte APIs. The token can be generated with: `$ astartectl utils gen-jwt <service> -k <your-private-key>.pem`."
  app_env :jwt, :astarte_e2e, :jwt,
    os_env: "E2E_JWT",
    type: :binary,
    required: true

  @envdoc "Time interval between consecutive checks (in seconds)."
  app_env :check_interval_s, :astarte_e2e, :check_interval_s,
    os_env: "E2E_CHECK_INTERVAL_SECONDS",
    type: :integer,
    default: 60

  @envdoc "The port used to expose AstarteE2E's metrics and trigger endpoints. Defaults to 4010."
  app_env :port, :astarte_e2e, :port,
    os_env: "E2E_PORT",
    type: :integer,
    default: 4010

  @envdoc "Overall number of consistency checks repetitions. Defaults to 0, corresponding to infinite checks."
  app_env :check_repetitions, :astarte_e2e, :check_repetitions,
    os_env: "E2E_CHECK_REPETITIONS",
    type: PositiveIntegerOrInfinity,
    default: :infinity

  @envdoc "The amount of time (in seconds) the websocket client is allowed to wait for an incoming message. Defaults to 10 seconds."
  app_env :client_timeout_s, :astarte_e2e, :client_timeout_s,
    os_env: "E2E_CLIENT_TIMEOUT_SECONDS",
    type: :pos_integer,
    default: 10

  @envdoc "The maximum number of consecutive timeouts before the websocket client is allowed to crash. Defaults to 10."
  app_env :client_max_timeouts, :astarte_e2e, :client_max_timeouts,
    os_env: "E2E_CLIENT_MAX_TIMEOUTS",
    type: :pos_integer,
    default: 10

  @envdoc "The number of consecutive failures before an email alert is sent. Defaults to 10."
  app_env :failures_before_alert, :astarte_e2e, :failures_before_alert,
    os_env: "E2E_FAILURES_BEFORE_ALERT",
    type: :pos_integer,
    default: 10

  @envdoc "The comma-separated email recipients."
  app_env :mail_to_address, :astarte_e2e, :mail_to_address,
    os_env: "E2E_MAIL_TO_ADDRESS",
    type: ListOfStrings,
    default: ""

  @envdoc "The notification email sender."
  app_env :mail_from_address, :astarte_e2e, :mail_from_address,
    os_env: "E2E_MAIL_FROM_ADDRESS",
    type: NormalizedMailAddress,
    default: ""

  @envdoc "The subject of the notification email."
  app_env :mail_subject, :astarte_e2e, :mail_subject,
    os_env: "E2E_MAIL_SUBJECT",
    type: :binary,
    required: true

  @envdoc "The host for AstarteE2E trigger endpoints. Defaults to localhost."
  app_env :host, :astarte_e2e, :host,
    os_env: "E2E_HOST",
    type: :binary,
    default: "localhost"

  @envdoc "The protocol used for AstarteE2E trigger endpoints. Defaults to http."
  app_env :protocol, :astarte_e2e, :protocol,
    os_env: "E2E_PROTOCOL",
    type: :binary,
    default: "http"

  @envdoc """
  The mail service's API key. This env var must be set and valid to use the mail
  service.
  """
  app_env :mail_api_key, :astarte_e2e, :mail_api_key,
    os_env: "E2E_MAIL_API_KEY",
    type: :binary

  @envdoc """
  The mail domain. This env var must be set and valid to use the mailgun service.
  """
  app_env :mail_domain, :astarte_e2e, :mail_domain,
    os_env: "E2E_MAIL_DOMAIN",
    type: :binary

  @envdoc """
  The mail API base URI. This env var must be set and valid to use the mail service.
  """
  app_env :mail_api_base_uri, :astarte_e2e, :mail_api_base_uri,
    os_env: "E2E_MAIL_API_BASE_URI",
    type: :binary

  @envdoc """
  The mail service. Currently only "mailgun" and "sendgrid" are supported.
  This env var must be set and valid to use the mail service.
  """
  app_env :mail_service, :astarte_e2e, :mail_service,
    os_env: "E2E_MAIL_SERVICE",
    type: BambooMailAdapter

  @envdoc "Host for the AMQP consumer connection"
  app_env :amqp_consumer_host, :astarte_e2e, :amqp_consumer_host,
    os_env: "E2E_AMQP_CONSUMER_HOST",
    type: :binary,
    default: "localhost"

  @envdoc "Port for the AMQP consumer connection"
  app_env :amqp_consumer_port, :astarte_e2e, :amqp_consumer_port,
    os_env: "E2E_AMQP_CONSUMER_PORT",
    type: :integer,
    default: 5672

  @envdoc "Username for the AMQP consumer connection"
  app_env :amqp_consumer_username, :astarte_e2e, :amqp_consumer_username,
    os_env: "E2E_AMQP_CONSUMER_USERNAME",
    type: :binary,
    default: "guest"

  @envdoc "Password for the AMQP consumer connection"
  app_env :amqp_consumer_password, :astarte_e2e, :amqp_consumer_password,
    os_env: "E2E_AMQP_CONSUMER_PASSWORD",
    type: :binary,
    default: "guest"

  @envdoc "Virtual host for the AMQP consumer connection"
  app_env :amqp_consumer_virtual_host, :astarte_e2e, :amqp_consumer_virtual_host,
    os_env: "E2E_AMQP_CONSUMER_VIRTUAL_HOST",
    type: :binary,
    default: "/"

  @envdoc "The name of the AMQP queue created by the events consumer"
  app_env :events_queue_name, :astarte_e2e, :amqp_events_queue_name,
    os_env: "E2E_AMQP_EVENTS_QUEUE_NAME",
    type: :binary,
    default: "astarte_events"

  @envdoc "The AMQP consumer prefetch count."
  app_env :amqp_consumer_prefetch_count, :astarte_e2e, :amqp_consumer_prefetch_count,
    os_env: "E2E_AMQP_CONSUMER_PREFETCH_COUNT",
    type: :integer,
    default: 300

  @envdoc "Enable SSL. If not specified, SSL is disabled."
  app_env :amqp_consumer_ssl_enabled, :astarte_e2e, :amqp_consumer_ssl_enabled,
    os_env: "E2E_AMQP_CONSUMER_SSL_ENABLED",
    type: :boolean,
    default: false

  @envdoc "Specifies the certificates of the root Certificate Authorities to be trusted. When not specified, the bundled cURL certificate bundle will be used."
  app_env :amqp_consumer_ssl_ca_file, :astarte_e2e, :amqp_consumer_ssl_ca_file,
    os_env: "E2E_AMQP_CONSUMER_SSL_CA_FILE",
    type: :binary

  @envdoc "Disable Server Name Indication. Defaults to false."
  app_env :amqp_consumer_ssl_disable_sni, :astarte_e2e, :amqp_consumer_ssl_disable_sni,
    os_env: "E2E_AMQP_CONSUMER_SSL_DISABLE_SNI",
    type: :boolean,
    default: false

  @envdoc "Specify the hostname to be used in TLS Server Name Indication extension. If not specified, the amqp host will be used. This value is used only if Server Name Indication is enabled."
  app_env :amqp_consumer_ssl_custom_sni, :astarte_e2e, :amqp_consumer_ssl_custom_sni,
    os_env: "E2E_AMQP_CONSUMER_SSL_CUSTOM_SNI",
    type: :binary

  @envdoc "The number of connections to RabbitMQ used to consume events"
  app_env :events_consumer_connection_number,
          :astarte_e2e,
          :events_consumer_connection_number,
          type: :integer,
          default: 10

  @envdoc "The number of channels per RabbitMQ connection used to consume events"
  app_env :events_consumer_channels_per_connection_number,
          :astarte_e2e,
          :events_consumer_channels_per_connection_number,
          type: :integer,
          default: 10

  app_env :amqp_trigger_exchange_suffix, :astarte_e2e, :amqp_trigger_exchange_suffix,
    os_env: "E2E_AMQP_TRIGGER_EXCHANGE_SUFFIX",
    type: :binary,
    default: "e2e"

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

  def base_url! do
    "#{protocol!()}://#{host!()}:#{port!()}"
  end

  @spec device_opts() :: device_options()
  def device_opts do
    [
      pairing_url: pairing_url!(),
      realm: realm!(),
      ignore_ssl_errors: ignore_ssl_errors!()
    ]
  end

  @spec client_opts() :: client_options()
  def client_opts do
    [
      url: websocket_url!(),
      realm: realm!(),
      jwt: jwt!(),
      check_repetitions: check_repetitions!(),
      ignore_ssl_errors: ignore_ssl_errors!()
    ]
  end

  @spec scheduler_opts() :: scheduler_options()
  def scheduler_opts do
    [
      check_interval_s: check_interval_s!(),
      check_repetitions: check_repetitions!(),
      realm: realm!()
    ]
  end

  @spec notifier_opts() :: notifier_options()
  def notifier_opts do
    [mail_subject: mail_subject!()]
  end

  def service_notifier_config do
    case mail_service() do
      {:ok, Bamboo.MailgunAdapter} ->
        mailgun_config()

      {:ok, Bamboo.SendGridAdapter} ->
        sendgrid_config()

      _ ->
        fallback_config()
    end
  end

  defp mailgun_config do
    with {:ok, base_uri} <- mail_api_base_uri(),
         {:ok, domain} when not is_nil(domain) <- mail_domain(),
         {:ok, api_key} when not is_nil(api_key) <- mail_api_key(),
         {:ok, from} when from != "" <- mail_from_address(),
         {:ok, to} when to != "" <- mail_to_address() do
      %{
        chained_adapter: mail_service!(),
        api_key: api_key,
        domain: domain,
        base_uri: base_uri,
        hackney_opts: [
          recv_timeout: :timer.minutes(1)
        ]
      }
    else
      _ ->
        Logger.warning("Incomplete mail configuration. The Local Adapter will be used.",
          tag: "local_adapter_fallback"
        )

        fallback_config()
    end
  end

  defp sendgrid_config do
    with {:ok, base_uri} <- mail_api_base_uri(),
         {:ok, api_key} when not is_nil(api_key) <- mail_api_key(),
         {:ok, from} when from != "" <- mail_from_address(),
         {:ok, to} when to != "" <- mail_to_address() do
      %{
        chained_adapter: mail_service!(),
        api_key: api_key,
        base_uri: base_uri,
        hackney_opts: [
          recv_timeout: :timer.minutes(1)
        ]
      }
    else
      _ ->
        Logger.warning("Incomplete mail configuration. The Local Adapter will be used.",
          tag: "local_adapter_fallback"
        )

        fallback_config()
    end
  end

  defp fallback_config do
    %{chained_adapter: Bamboo.LocalAdapter}
  end

  def amqp_consumer_options! do
    [
      host: amqp_consumer_host!(),
      port: amqp_consumer_port!(),
      username: amqp_consumer_username!(),
      password: amqp_consumer_password!(),
      virtual_host: amqp_consumer_virtual_host!(),
      channel_max: events_consumer_channels_per_connection_number!()
    ]
    |> populate_ssl_options()
  end

  defp populate_ssl_options(options) do
    if amqp_consumer_ssl_enabled!() do
      ssl_options = build_ssl_options()
      Keyword.put(options, :ssl_options, ssl_options)
    else
      options
    end
  end

  defp build_ssl_options() do
    [
      cacertfile: amqp_consumer_ssl_ca_file!() || CAStore.file_path(),
      verify: :verify_peer,
      depth: 10
    ]
    |> populate_sni()
  end

  defp populate_sni(ssl_options) do
    if amqp_consumer_ssl_disable_sni!() do
      Keyword.put(ssl_options, :server_name_indication, :disable)
    else
      server_name = amqp_consumer_ssl_custom_sni!() || amqp_consumer_host!()
      Keyword.put(ssl_options, :server_name_indication, to_charlist(server_name))
    end
  end

  def events_consumer_pool_config!() do
    [
      name: {:local, :amqp_trigger_consumer_pool},
      worker_module: ExRabbitPool.Worker.RabbitConnection,
      size: events_consumer_connection_number!(),
      max_overflow: 0
    ]
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
