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

defmodule Astarte.HousekeepingWeb do
  @moduledoc """
  A module that keeps using definitions for controllers,
  views and so on.

  This can be used in your application as:

      use Astarte.HousekeepingWeb, :controller
      use Astarte.HousekeepingWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below.
  """

  def controller do
    quote do
      use Phoenix.Controller, formats: [json: "View"]
      use Gettext, backend: Astarte.HousekeepingWeb.Gettext

      import Astarte.HousekeepingWeb.Router.Helpers
      import Plug.Conn
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/astarte_housekeeping/web/templates",
        namespace: Astarte.HousekeepingWeb

      use Gettext, backend: Astarte.HousekeepingWeb.Gettext

      # Import convenience functions from controllers
      import Astarte.HousekeepingWeb.ErrorHelpers
      import Astarte.HousekeepingWeb.Router.Helpers
      import Phoenix.Controller, only: [get_csrf_token: 0, get_flash: 2, view_module: 1]
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Phoenix.Controller
      import Plug.Conn
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      use Gettext, backend: Astarte.HousekeepingWeb.Gettext
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
