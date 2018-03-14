#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.AppEngine.APIWeb.ErrorViewTest do
  use Astarte.AppEngine.APIWeb.ConnCase, async: true

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  test "renders 404.json" do
    assert render(Astarte.AppEngine.APIWeb.ErrorView, "404.json", []) ==
             %{errors: %{detail: "Page not found"}}
  end

  test "render 500.json" do
    assert render(Astarte.AppEngine.APIWeb.ErrorView, "500.json", []) ==
             %{errors: %{detail: "Internal server error"}}
  end

  test "render any other" do
    assert render(Astarte.AppEngine.APIWeb.ErrorView, "505.json", []) ==
             %{errors: %{detail: "Internal server error"}}
  end
end
