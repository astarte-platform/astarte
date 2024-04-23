#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.Housekeeping.Config do
  alias Astarte.DataAccess.Config, as: DataAccessConfig
  alias Astarte.RPC.Config, as: RPCConfig
  use Skogsra

  @envdoc "Replication factor for the astarte keyspace, defaults to 1"
  app_env :astarte_keyspace_replication_factor,
          :astarte_housekeeping,
          :astarte_keyspace_replication_factor,
          os_env: "HOUSEKEEPING_ASTARTE_KEYSPACE_REPLICATION_FACTOR",
          type: :integer,
          default: 1

  @envdoc "The port where the housekeeping metrics endpoint will be exposed."
  app_env :port, :astarte_housekeeping, :port,
    os_env: "HOUSEKEEPING_PORT",
    type: :integer,
    default: 4000

  @envdoc """
  By default Astarte Housekeeping doesn't support realm deletion. Set this variable to true to
  enable this feature. WARNING: this feature can cause permanent data loss when deleting a realm.
  """
  app_env :enable_realm_deletion, :astarte_housekeeping, :enable_realm_deletion,
    os_env: "HOUSEKEEPING_ENABLE_REALM_DELETION",
    type: :boolean,
    default: false

  defdelegate astarte_instance_id!, to: DataAccessConfig
  defdelegate astarte_instance_id, to: DataAccessConfig

  defdelegate xandra_nodes, to: DataAccessConfig
  defdelegate xandra_nodes!, to: DataAccessConfig

  defdelegate xandra_options!, to: DataAccessConfig

  defdelegate amqp_connection_username, to: RPCConfig
  defdelegate amqp_connection_username!, to: RPCConfig

  defdelegate amqp_connection_password, to: RPCConfig
  defdelegate amqp_connection_password!, to: RPCConfig

  defdelegate amqp_connection_host, to: RPCConfig
  defdelegate amqp_connection_host!, to: RPCConfig

  defdelegate amqp_connection_virtual_host, to: RPCConfig
  defdelegate amqp_connection_virtual_host!, to: RPCConfig

  defdelegate amqp_connection_port, to: RPCConfig
  defdelegate amqp_connection_port!, to: RPCConfig

  defdelegate amqp_prefetch_count, to: RPCConfig
  defdelegate amqp_prefetch_count!, to: RPCConfig

  defdelegate amqp_queue_max_length, to: RPCConfig
  defdelegate amqp_queue_max_length!, to: RPCConfig
end
