#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.TriggerEngine.Config do
  @moduledoc """
  This module handles the configuration of TriggerEngine
  """

  alias Astarte.DataAccess.Config, as: DataAccessConfig

  use Skogsra

  @envdoc "Host for the AMQP consumer connection"
  app_env :amqp_consumer_host, :astarte_trigger_engine, :amqp_consumer_host,
    os_env: "TRIGGER_ENGINE_AMQP_CONSUMER_HOST",
    type: :binary,
    default: "localhost"

  @envdoc "Port for the AMQP consumer connection"
  app_env :amqp_consumer_port, :astarte_trigger_engine, :amqp_consumer_port,
    os_env: "TRIGGER_ENGINE_AMQP_CONSUMER_PORT",
    type: :integer,
    default: 5672

  @envdoc "Username for the AMQP consumer connection"
  app_env :amqp_consumer_username, :astarte_trigger_engine, :amqp_consumer_username,
    os_env: "TRIGGER_ENGINE_AMQP_CONSUMER_USERNAME",
    type: :binary,
    default: "guest"

  @envdoc "Password for the AMQP consumer connection"
  app_env :amqp_consumer_password, :astarte_trigger_engine, :amqp_consumer_password,
    os_env: "TRIGGER_ENGINE_AMQP_CONSUMER_PASSWORD",
    type: :binary,
    default: "guest"

  @envdoc "Virtual host for the AMQP consumer connection"
  app_env :amqp_consumer_virtual_host, :astarte_trigger_engine, :amqp_consumer_virtual_host,
    os_env: "TRIGGER_ENGINE_AMQP_CONSUMER_VIRTUAL_HOST",
    type: :binary,
    default: "/"

  @envdoc "The name of the AMQP queue created by the events consumer"
  app_env :events_queue_name, :astarte_trigger_engine, :amqp_events_queue_name,
    os_env: "TRIGGER_ENGINE_AMQP_EVENTS_QUEUE_NAME",
    type: :binary,
    default: "astarte_events"

  @envdoc "The name of the exchange on which events are published"
  app_env :events_exchange_name, :astarte_trigger_engine, :amqp_events_exchange_name,
    os_env: "TRIGGER_ENGINE_AMQP_EVENTS_EXCHANGE_NAME",
    type: :binary,
    default: "astarte_events"

  @envdoc "The routing_key used to bind to TriggerEngine specific events"
  app_env :events_routing_key, :astarte_trigger_engine, :amqp_events_routing_key,
    os_env: "TRIGGER_ENGINE_AMQP_EVENTS_ROUTING_KEY",
    type: :binary,
    default: "trigger_engine"

  @envdoc "Enable SSL. If not specified, SSL is disabled."
  app_env :amqp_consumer_ssl_enabled, :astarte_trigger_engine, :amqp_consumer_ssl_enabled,
    os_env: "TRIGGER_ENGINE_AMQP_CONSUMER_SSL_ENABLED",
    type: :boolean,
    default: false

  @envdoc "Specifies the certificates of the root Certificate Authorities to be trusted. When not specified, the bundled cURL certificate bundle will be used."
  app_env :amqp_consumer_ssl_ca_file, :astarte_trigger_engine, :amqp_consumer_ssl_ca_file,
    os_env: "TRIGGER_ENGINE_AMQP_CONSUMER_SSL_CA_FILE",
    type: :binary

  @envdoc "Disable Server Name Indication. Defaults to false."
  app_env :amqp_consumer_ssl_disable_sni, :astarte_trigger_engine, :amqp_consumer_ssl_disable_sni,
    os_env: "TRIGGER_ENGINE_AMQP_CONSUMER_SSL_DISABLE_SNI",
    type: :boolean,
    default: false

  @envdoc "Specify the hostname to be used in TLS Server Name Indication extension. If not specified, the amqp host will be used. This value is used only if Server Name Indication is enabled."
  app_env :amqp_consumer_ssl_custom_sni, :astarte_trigger_engine, :amqp_consumer_ssl_custom_sni,
    os_env: "TRIGGER_ENGINE_AMQP_CONSUMER_SSL_CUSTOM_SNI",
    type: :binary

  @envdoc "The port where Trigger Engine metrics will be exposed."
  app_env :port, :astarte_trigger_engine, :port,
    os_env: "TRIGGER_ENGINE_PORT",
    type: :integer,
    default: 4007

  @envdoc "The module used to consume events, used for tests with Mox"
  app_env :events_consumer, :astarte_trigger_engine, :events_consumer,
    os_env: "TRIGGER_ENGINE_EVENTS_CONSUMER",
    type: :module,
    binding_skip: [:system],
    default: Astarte.TriggerEngine.EventsConsumer

  @doc """
  Returns the AMQP events consumer connection options
  """
  @type ssl_option ::
          {:cacertfile, String.t()}
          | {:verify, :verify_peer}
          | {:server_name_indication, charlist() | :disable}
  @type ssl_options :: :none | [ssl_option]

  @type options ::
          {:username, String.t()}
          | {:password, String.t()}
          | {:virtual_host, String.t()}
          | {:host, String.t()}
          | {:port, integer()}
          | {:ssl_options, ssl_options}

  @spec amqp_consumer_options!() :: [options]
  def amqp_consumer_options! do
    [
      host: amqp_consumer_host!(),
      port: amqp_consumer_port!(),
      username: amqp_consumer_username!(),
      password: amqp_consumer_password!(),
      virtual_host: amqp_consumer_virtual_host!()
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
      verify: :verify_peer
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

  @doc "A list of host values of accessible Cassandra nodes formatted in the Xandra format"
  defdelegate xandra_nodes, to: DataAccessConfig
  defdelegate xandra_nodes!, to: DataAccessConfig

  @doc "A list of {host, port} values of accessible Cassandra nodes in a CQEx compliant format"
  defdelegate cqex_nodes, to: DataAccessConfig
  defdelegate cqex_nodes!, to: DataAccessConfig
end
