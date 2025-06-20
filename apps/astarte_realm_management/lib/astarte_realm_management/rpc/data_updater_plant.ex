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

defmodule Astarte.RealmManagement.RPC.DataUpdaterPlant.Trigger do
  @moduledoc """
  This module sends RPC to DataUpdaterPlant
  """

  require Logger

  @rpc_behaviour Application.compile_env(
                   :astarte_realm_management,
                   :data_updater_plant_rpc_client,
                   Astarte.RealmManagement.RPC.DataUpdaterPlant.Client
                 )

  def install_persistent_triggers(request_data) do
    @rpc_behaviour.install_persistent_triggers(request_data)
  end
end
