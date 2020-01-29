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

  alias Astarte.Pairing.CFSSLCredentials

  def init! do
    if Application.fetch_env(:astarte_pairing, :ca_cert) == :error do
      case CFSSLCredentials.ca_cert() do
        {:ok, cert} ->
          Application.put_env(:astarte_pairing, :ca_cert, cert)

        {:error, _reason} ->
          raise "no CA certificate available"
      end
    end
  end

  @doc """
  Returns the broker_url contained in the config.

  Raises if it doesn't exist since it's required.
  """
  def broker_url! do
    Application.fetch_env!(:astarte_pairing, :broker_url)
  end

  @doc """
  Returns the cassandra node configuration
  """
  def cassandra_node do
    Application.get_env(:cqerl, :cassandra_nodes)
    |> List.first()
  end

  @doc """
  Returns Cassandra nodes formatted in the Xandra format.
  """
  def xandra_nodes do
    Application.get_env(:astarte_data_access, :cassandra_nodes, "localhost")
    |> String.split(",")
  end

  @doc """
  Returns the CFSSL base_url
  """
  def cfssl_url do
    Application.fetch_env!(:astarte_pairing, :cfssl_url)
  end

  @doc """
  Returns the PEM encoded CFSSL CA certificate
  """
  def ca_cert do
    Application.fetch_env!(:astarte_pairing, :ca_cert)
  end
end
