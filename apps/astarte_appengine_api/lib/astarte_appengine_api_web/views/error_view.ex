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

defmodule Astarte.AppEngine.APIWeb.ErrorView do
  use Astarte.AppEngine.APIWeb, :view

  def render("400.json", _assigns) do
    %{errors: %{detail: "Bad request"}}
  end

  def render("422_unexpected_value_type.json", %{expected: expected} = _assigns) do
    %{errors: %{detail: "Unexpected value type", expected_type: expected}}
  end

  def render("422_value_size_exceeded.json", _assigns) do
    %{errors: %{detail: "Value size exceeds size limits"}}
  end

  def render("403_cannot_write_to_device_owned.json", _assigns) do
    %{errors: %{detail: "Cannot write to device owned resource"}}
  end

  def render("403_read_only_resource.json", _assigns) do
    %{errors: %{detail: "Cannot write to read-only resource"}}
  end

  def render("404.json", _assigns) do
    %{errors: %{detail: "Not found"}}
  end

  def render("404_device.json", _assigns) do
    %{errors: %{detail: "Device not found"}}
  end

  def render("404_endpoint_not_found.json", _assigns) do
    %{errors: %{detail: "Endpoint not found"}}
  end

  def render("404_interface_not_found.json", _assigns) do
    %{errors: %{detail: "Interface not found"}}
  end

  def render("404_interface_not_in_introspection.json", _assigns) do
    %{errors: %{detail: "Interface not found in device introspection"}}
  end

  def render("404_path.json", _assigns) do
    %{errors: %{detail: "Path not found"}}
  end

  def render("500.json", _assigns) do
    %{errors: %{detail: "Internal server error"}}
  end

  def render("401.json", _assigns) do
    %{errors: %{detail: "Unauthorized"}}
  end

  def render("403.json", _assigns) do
    %{errors: %{detail: "Forbidden"}}
  end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def template_not_found(_template, assigns) do
    render("500.json", assigns)
  end
end
