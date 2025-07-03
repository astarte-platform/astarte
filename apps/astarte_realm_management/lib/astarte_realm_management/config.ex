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

defmodule Astarte.RealmManagement.Config do
  @moduledoc """
  This module contains functions to access the configuration
  """

  use Skogsra

  alias Astarte.DataAccess.Config, as: DataAccessConfig

  @envdoc """
  "Disables the authentication. CHANGING IT TO TRUE IS GENERALLY A REALLY BAD IDEA IN A PRODUCTION ENVIRONMENT, IF YOU DON'T KNOW WHAT YOU ARE DOING.
  """
  app_env :disable_authentication, :astarte_realm_management, :disable_authentication,
    os_env: "REALM_MANAGEMENT_API_DISABLE_AUTHENTICATION",
    type: :boolean,
    default: false

  @doc """
  Returns true if the authentication is disabled.
  """
  def authentication_disabled?, do: disable_authentication!()

  @doc """
  Returns Cassandra nodes formatted in the Xandra format.
  """
  defdelegate xandra_options!, to: DataAccessConfig
end
