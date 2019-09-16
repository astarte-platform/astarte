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

  def render("404_group.json", _assigns) do
    %{errors: %{detail: "Group not found"}}
  end

  def render("409_group_already_exists.json", _assigns) do
    %{errors: %{detail: "Group already exists"}}
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
