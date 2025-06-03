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

defmodule Astarte.RealmManagement.Config do
  @moduledoc """
  This module helps the access to the runtime configuration of Astarte RealmManagement
  """

  use Skogsra
  alias Astarte.DataAccess.Config, as: DataAccessConfig

  @envdoc """
  Specifies the certificates of the root Certificate Authorities to be trusted.
  When not specified, the bundled cURL certificate bundle will be used.
  """
  app_env :ssl_ca_file, :astarte_data_access, :ssl_ca_file,
    os_env: "CASSANDRA_SSL_CA_FILE",
    type: :binary,
    default: CAStore.file_path()

  @envdoc "The port where Realm Management metrics will be exposed."
  app_env :port, :astarte_realm_management, :port,
    os_env: "REALM_MANAGEMENT_PORT",
    type: :integer,
    default: 4000

  @doc """
  Returns Cassandra nodes formatted in the Xandra format.
  """
  defdelegate xandra_options!, to: DataAccessConfig
end
