#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.AppEngine.APIWeb.ErrorViewTest do
  use Astarte.AppEngine.APIWeb.ConnCase, async: true

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  test "renders 400.json" do
    assert render(Astarte.AppEngine.APIWeb.ErrorView, "400.json", []) ==
             %{errors: %{detail: "Bad request"}}
  end

  test "renders 403_cannot_write_to_device_owned.json" do
    assert render(Astarte.AppEngine.APIWeb.ErrorView, "403_cannot_write_to_device_owned.json", []) ==
             %{errors: %{detail: "Cannot write to device owned resource"}}
  end

  test "renders 403_read_only_resource.json" do
    assert render(Astarte.AppEngine.APIWeb.ErrorView, "403_read_only_resource.json", []) ==
             %{errors: %{detail: "Cannot write to read-only resource"}}
  end

  test "renders 404_endpoint_not_found.json" do
    assert render(Astarte.AppEngine.APIWeb.ErrorView, "404_endpoint_not_found.json", []) ==
             %{errors: %{detail: "Endpoint not found"}}
  end

  test "renders 404_interface_not_found.json" do
    assert render(Astarte.AppEngine.APIWeb.ErrorView, "404_interface_not_found.json", []) ==
             %{errors: %{detail: "Interface not found"}}
  end

  test "renders 404_interface_not_in_introspection.json" do
    assert render(
             Astarte.AppEngine.APIWeb.ErrorView,
             "404_interface_not_in_introspection.json",
             []
           ) == %{errors: %{detail: "Interface not found in device introspection"}}
  end

  test "renders 404_path.json" do
    assert render(Astarte.AppEngine.APIWeb.ErrorView, "404_path.json", []) ==
             %{errors: %{detail: "Path not found"}}
  end

  test "renders 404.json" do
    assert render(Astarte.AppEngine.APIWeb.ErrorView, "404.json", []) ==
             %{errors: %{detail: "Not found"}}
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
