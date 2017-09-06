defmodule Astarte.Housekeeping.API.Web do
  @moduledoc """
  A module that keeps using definitions for controllers,
  views and so on.

  This can be used in your application as:

      use Astarte.Housekeeping.API.Web, :controller
      use Astarte.Housekeeping.API.Web, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: Astarte.Housekeeping.API.Web
      import Plug.Conn
      import Astarte.Housekeeping.API.Web.Router.Helpers
      import Astarte.Housekeeping.API.Web.Gettext
    end
  end

  def view do
    quote do
      use Phoenix.View, root: "lib/astarte_housekeeping_api/web/templates",
                        namespace: Astarte.Housekeeping.API.Web

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [get_csrf_token: 0, get_flash: 2, view_module: 1]

      import Astarte.Housekeeping.API.Web.Router.Helpers
      import Astarte.Housekeeping.API.Web.ErrorHelpers
      import Astarte.Housekeeping.API.Web.Gettext
    end
  end

  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import Astarte.Housekeeping.API.Web.Gettext
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
