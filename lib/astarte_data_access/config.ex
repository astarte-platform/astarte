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

defmodule Astarte.DataAccess.Config do
  @moduledoc """
  This module helps the access to the runtime configuration of Astarte
  Data Access
  """

  alias Astarte.DataAccess.Config.CQExNodes
  alias Astarte.DataAccess.Config.XandraNodes

  use Skogsra

  @type ssl_option ::
          {:cacertfile, String.t()}
          | {:verify, :verify_peer}
          | {:server_name_indication, :disable | charlist()}
  @type ssl_options :: :none | [ssl_option]
  @type auth_options :: {module(), [{String.t(), String.t()}]}
  @type cqex_opts ::
          {:ssl, ssl_options}
          | {:auth, auth_options}
          | {:keyspace, String.t()}

  @envdoc "A list of host values of accessible Cassandra nodes formatted in the Xandra format"
  app_env :xandra_nodes, :astarte_data_access, :xandra_nodes,
    os_env: "CASSANDRA_NODES",
    type: XandraNodes,
    default: ["localhost:9042"]

  @envdoc "A list of {host, port} values of accessible Cassandra nodes in a cqex compliant format"
  app_env :cqex_nodes, :astarte_data_access, :cqex_nodes,
    os_env: "CASSANDRA_NODES",
    type: CQExNodes,
    default: [{"localhost", 9042}]

  @envdoc """
  The username used to log into cassandra. Defaults to "cassandra".
  """
  app_env :cassandra_username, :astarte_data_access, :cassandra_username,
    os_env: "CASSANDRA_USERNAME",
    type: :binary,
    default: "cassandra"

  @envdoc """
  The password used to log into cassandra. Defaults to 'cassandra'.
  """
  app_env :cassandra_password, :astarte_data_access, :cassandra_password,
    os_env: "CASSANDRA_PASSWORD",
    type: :binary,
    default: "cassandra"

  @envdoc "The number of connections to start for the pool, Defaults to 1."
  app_env :pool_size, :astarte_data_access, :pool_size,
    os_env: "CASSANDRA_POOL_SIZE",
    type: :integer,
    default: 1

  @envdoc "Enable SSL for Cassandra connections. Defaults to false."
  app_env :ssl_enabled, :astarte_data_access, :ssl_enabled,
    os_env: "CASSANDRA_SSL_ENABLED",
    type: :boolean,
    default: false

  @envdoc "Disable Server Name Indication. Defaults to false."
  app_env :ssl_disable_sni, :astarte_data_access, :ssl_disable_sni,
    os_env: "CASSANDRA_SSL_DISABLE_SNI",
    type: :boolean,
    default: false

  @envdoc """
  Specify the hostname to be used in TLS Server Name Indication extension.
  If not specified, the cassandra nodes will be used. This value is used
  only if Server Name Indication is enabled.
  """
  app_env :ssl_custom_sni, :astarte_data_access, :ssl_custom_sni,
    os_env: "CASSANDRA_SSL_CUSTOM_SNI",
    type: :binary

  @envdoc """
  Specifies the certificates of the root Certificate Authorities to be trusted.
  When not specified, the bundled cURL certificate bundle will be used.
  """
  app_env :ssl_ca_file, :astarte_data_access, :ssl_ca_file,
    os_env: "CASSANDRA_SSL_CA_FILE",
    type: :binary,
    default: CAStore.file_path()

  @envdoc """
  Discover nodes in the same cluster as specified in CASSANDRA_NODES. If your Cassandra
  instance is outside of your network, enabling the autodiscovery leads to connection failures.
  Defaults to false.
  """
  app_env :autodiscovery_enabled, :astarte_data_access, :autodiscovery_enabled,
    os_env: "CASSANDRA_AUTODISCOVERY_ENABLED",
    type: :boolean,
    default: false

  defp populate_xandra_ssl_options(options) do
    if ssl_enabled!() do
      ssl_options = build_ssl_options()
      Keyword.put(options, :transport_options, ssl_options)
    else
      options
    end
  end

  defp populate_cqex_ssl_options(options) do
    if ssl_enabled!() do
      ssl_options = build_ssl_options()
      Keyword.put(options, :ssl, ssl_options)
    else
      options
    end
  end

  defp build_ssl_options do
    [
      cacertfile: ssl_ca_file!(),
      verify: :verify_peer,
      server_name_indication: :disable
    ]
  end

  defp xandra_authentication_options! do
    {Xandra.Authenticator.Password,
     [
       username: cassandra_username!(),
       password: cassandra_password!()
     ]}
  end

  defp cqex_authentication_options! do
    {
      :cqerl_auth_plain_handler,
      [{cassandra_username!(), cassandra_password!()}]
    }
  end

  @spec xandra_options!() :: Xandra.start_options()
  def xandra_options! do
    [
      nodes: xandra_nodes!(),
      authentication: xandra_authentication_options!(),
      pool_size: pool_size!(),
      encryption: ssl_enabled!(),
      autodiscovery: autodiscovery_enabled!()
    ]
    |> populate_xandra_ssl_options()
  end

  @spec cqex_options!() :: [cqex_opts]
  def(cqex_options!()) do
    [
      auth: cqex_authentication_options!()
    ]
    |> populate_cqex_ssl_options()
  end
end
