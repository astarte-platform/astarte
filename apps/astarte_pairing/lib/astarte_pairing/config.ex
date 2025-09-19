#
# This file is part of Astarte.
#
# Copyright 2017-2025 SECO Mind Srl
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

defmodule Astarte.Pairing.Config do
  @moduledoc """
  This module contains functions to access the configuration
  """

  use Skogsra

  alias Astarte.DataAccess.Config, as: DataAccessConfig
  alias Astarte.Pairing.CFSSLCredentials
  alias Astarte.Pairing.Config.CQExNodes

  @envdoc "The external broker URL which should be used by devices."
  app_env :broker_url, :astarte_pairing, :broker_url,
    os_env: "PAIRING_BROKER_URL",
    type: :binary,
    required: true

  @envdoc "URL to the running CFSSL instance for device certificate generation."
  app_env :cfssl_url, :astarte_pairing, :cfssl_url,
    os_env: "PAIRING_CFSSL_URL",
    type: :binary,
    default: "http://localhost:8888"

  @envdoc "The CA certificate."
  app_env :ca_cert, :astarte_pairing, :ca_cert,
    os_env: "PAIRING_CA_CERT",
    type: :binary

  @envdoc "A list of {host, port} values of accessible Cassandra nodes in a cqex compliant format"
  app_env :cqex_nodes, :astarte_pairing, :cqex_nodes,
    os_env: "CASSANDRA_NODES",
    type: CQExNodes,
    default: [{"localhost", 9042}]

  def init! do
    if {:ok, nil} == ca_cert() do
      case CFSSLCredentials.ca_cert() do
        {:ok, cert} ->
          put_ca_cert(cert)

        {:error, _reason} ->
          raise "No CA certificate available."
      end
    end
  end

  @envdoc """
  Disables JWT authentication for agent's endpoints. CHANGING IT TO TRUE IS GENERALLY A REALLY BAD IDEA IN A PRODUCTION ENVIRONMENT, IF YOU DON'T KNOW WHAT YOU ARE DOING.
  """
  app_env :disable_authentication, :astarte_pairing, :disable_authentication,
    os_env: "PAIRING_API_DISABLE_AUTHENTICATION",
    type: :boolean,
    default: false

  @envdoc """
  "The handling method for database events. The default is `expose`, which means that the events are exposed trough telemetry. The other possible value, `log`, means that the events are logged instead."
  """
  app_env :database_events_handling_method,
          :astarte_realm_management,
          :database_events_handling_method,
          os_env: "DATABASE_EVENTS_HANDLING_METHOD",
          type: Astarte.Pairing.Config.TelemetryType,
          default: :expose

  @doc """
  Returns the cassandra node configuration
  """
  @spec cassandra_node!() :: {String.t(), integer()}
  def cassandra_node!, do: Enum.random(cqex_nodes!())

  @doc """
  Returns Cassandra nodes formatted in the Xandra format.
  """
  defdelegate xandra_nodes, to: DataAccessConfig
  defdelegate xandra_nodes!, to: DataAccessConfig

  defdelegate xandra_options!, to: DataAccessConfig

  defdelegate astarte_instance_id!, to: DataAccessConfig
  defdelegate astarte_instance_id, to: DataAccessConfig

  @doc """
  Returns true if the authentication for the agent is disabled.
  Credential requests made by devices are always authenticated, even it this is true.
  """
  def authentication_disabled?, do: disable_authentication!()
end
