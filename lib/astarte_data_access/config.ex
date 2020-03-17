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
end
