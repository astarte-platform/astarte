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

defmodule Astarte.RealmManagement.Config do
  @moduledoc """
  This module helps the access to the runtime configuration of Astarte RealmManagement
  """

  use Skogsra
  alias Astarte.DataAccess.Config, as: DataAccessConfig

  @envdoc "The port where Realm Management metrics will be exposed."
  app_env :port, :astarte_realm_management, :port,
    os_env: "REALM_MANAGEMENT_PORT",
    type: :integer,
    default: 4000

  @envdoc "Specify whether to allow setting a custom consumer prefetch count for trigger policy queues (experimental feature)."
  app_env :allow_trigger_policy_prefetch_count,
          :astarte_realm_management,
          :allow_trigger_policy_prefetch_count,
          os_env: "REALM_MANAGEMENT_ALLOW_TRIGGER_POLICY_PREFETCH_COUNT",
          type: :boolean,
          default: false

  def cassandra_node!, do: Enum.random(cqex_nodes!())

  @doc """
  Returns Cassandra nodes formatted in the Xandra format.
  """
  defdelegate xandra_nodes, to: DataAccessConfig
  defdelegate xandra_nodes!, to: DataAccessConfig

  @doc """
  Returns Cassandra nodes formatted in the CQEx format.
  """
  defdelegate cqex_nodes, to: DataAccessConfig
  defdelegate cqex_nodes!, to: DataAccessConfig

  defdelegate xandra_options!, to: DataAccessConfig
  defdelegate cqex_options!, to: DataAccessConfig
end
