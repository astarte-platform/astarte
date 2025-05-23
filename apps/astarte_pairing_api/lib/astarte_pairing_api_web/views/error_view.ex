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
#

defmodule Astarte.Pairing.APIWeb.ErrorView do
  use Astarte.Pairing.APIWeb, :view

  def render("400.json", _assigns) do
    %{errors: %{detail: "Bad request"}}
  end

  def render("401.json", _assigns) do
    %{errors: %{detail: "Unauthorized"}}
  end

  def render("403.json", _assigns) do
    %{errors: %{detail: "Forbidden"}}
  end

  def render("missing_token.json", _assigns) do
    %{errors: %{detail: "Missing authorization token"}}
  end

  def render("invalid_token.json", _assigns) do
    %{errors: %{detail: "Invalid JWT token"}}
  end

  def render("invalid_auth_path.json", _assigns) do
    %{
      errors: %{
        detail: "Authorization failed due to an invalid path"
      }
    }
  end

  def render("authorization_path_not_matched.json", %{method: method, path: path}) do
    %{
      errors: %{
        detail: "Unauthorized access to #{method} #{path}. Please verify your permissions"
      }
    }
  end

  def render("404.json", _assigns) do
    %{errors: %{detail: "Page not found"}}
  end

  def render("404_device_not_found.json", _assigns) do
    %{errors: %{detail: "Device not found"}}
  end

  def render("500.json", _assigns) do
    %{errors: %{detail: "Internal server error"}}
  end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def template_not_found(_template, assigns) do
    render("500.json", assigns)
  end
end
