#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.RealmManagement.API.DataCase do
  use ExUnit.CaseTemplate

  setup do
    realm = "autotestrealm#{System.unique_integer([:positive])}"
    agent_name = :"test_agent_#{System.unique_integer([:positive])}"

    start_supervised!({Astarte.RealmManagement.API.Helpers.RPCMock.DB, agent_name})

    Process.put(:current_agent, agent_name)

    %{realm: realm}
  end
end
