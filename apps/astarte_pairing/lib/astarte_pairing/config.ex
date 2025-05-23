#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
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
  This module helps the access to the runtime configuration of Astarte Pairing
  """

  use Skogsra

  alias Astarte.Pairing.CFSSLCredentials
  alias Astarte.DataAccess.Config, as: DataAccessConfig

  @envdoc "The port where Pairing metrics will be exposed."
  app_env :port, :astarte_pairing, :port,
    os_env: "PAIRING_PORT",
    type: :integer,
    default: 4000

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

  defdelegate cqex_nodes, to: DataAccessConfig
  defdelegate cqex_nodes!, to: DataAccessConfig

  defdelegate xandra_options!, to: DataAccessConfig
  defdelegate cqex_options!, to: DataAccessConfig

  defdelegate astarte_instance_id!, to: DataAccessConfig
  defdelegate astarte_instance_id, to: DataAccessConfig
end
