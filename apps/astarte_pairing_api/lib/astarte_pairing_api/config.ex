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

defmodule Astarte.Pairing.API.Config do
  @moduledoc """
  This module contains functions to access the configuration
  """

  use Skogsra

  alias Astarte.Pairing.API.CFSSLCredentials
  alias Astarte.DataAccess.Config, as: DataAccessConfig
  alias Astarte.Pairing.API.Config.CQExNodes

  @envdoc "The external broker URL which should be used by devices."
  app_env :broker_url, :astarte_pairing_api, :broker_url,
    os_env: "PAIRING_BROKER_URL",
    type: :binary,
    required: true

  @envdoc "URL to the running CFSSL instance for device certificate generation."
  app_env :cfssl_url, :astarte_pairing_api, :cfssl_url,
    os_env: "PAIRING_CFSSL_URL",
    type: :binary,
    default: "http://localhost:8888"

  @envdoc "The CA certificate."
  app_env :ca_cert, :astarte_pairing_api, :ca_cert,
    os_env: "PAIRING_CA_CERT",
    type: :binary

  @envdoc "A list of {host, port} values of accessible Cassandra nodes in a cqex compliant format"
  app_env :cqex_nodes, :astarte_pairing_api, :cqex_nodes,
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
  app_env :disable_authentication, :astarte_pairing_api, :disable_authentication,
    os_env: "PAIRING_API_DISABLE_AUTHENTICATION",
    type: :binary,
    default: false

  @envdoc "The RPC Client."
  app_env :rpc_client, :astarte_pairing_api, :rpc_client,
    os_env: "PAIRING_API_RPC_CLIENT",
    type: :module,
    binding_skip: [:system],
    default: Astarte.RPC.AMQP.Client

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
