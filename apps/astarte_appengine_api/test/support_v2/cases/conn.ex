#
# This file is part of Astarte.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Astarte.Test.Cases.Conn do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import Astarte.AppEngine.APIWeb.Router.Helpers

      # The default endpoint for testing
      @endpoint Astarte.AppEngine.APIWeb.Endpoint
    end
  end

  alias Astarte.Test.Setups.Conn, as: ConnSetup

  setup_all [
    {ConnSetup, :create_conn},
    {ConnSetup, :jwt},
    {ConnSetup, :auth_conn}
  ]
end
