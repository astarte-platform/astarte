#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
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

defmodule Astarte.RealmManagement.APIWeb.InterfaceView do
  use Astarte.RealmManagement.APIWeb, :view

  def render("index.json", %{interfaces: interfaces}) do
    %{data: interfaces}
  end

  def render("show.json", %{interface: interface}) do
    %{data: interface}
  end

  def render("already_installed_interface.json", _assigns) do
    %{errors: %{detail: "Interface already exists"}}
  end

  def render("interface_name_collision.json", _assigns) do
    %{
      errors: %{
        detail:
          "Interface name collision detected. Make sure that the difference between " <>
            "two interface names is not limited to the casing or the presence of hyphens."
      }
    }
  end

  def render("name_not_matching.json", _assigns) do
    %{errors: %{detail: "Interface name doesn't match the one in the interface json"}}
  end

  def render("major_version_not_matching.json", _assigns) do
    %{errors: %{detail: "Interface major version doesn't match the one in the interface json"}}
  end

  def render("interface_major_version_does_not_exist.json", _assigns) do
    %{errors: %{detail: "Interface major not found"}}
  end

  def render("minor_version_not_increased.json", _assigns) do
    %{errors: %{detail: "Interface minor version was not increased"}}
  end

  def render("invalid_update.json", _assigns) do
    %{errors: %{detail: "Invalid update"}}
  end

  def render("downgrade_not_allowed.json", _assigns) do
    %{errors: %{detail: "Interface downgrade not allowed"}}
  end

  def render("missing_endpoints.json", _assigns) do
    %{errors: %{detail: "Interface update has missing endpoints"}}
  end

  def render("incompatible_endpoint_change.json", _assigns) do
    %{errors: %{detail: "Interface update contains incompatible endpoint changes"}}
  end

  def render("delete_forbidden.json", _assigns) do
    %{errors: %{detail: "Interface can't be deleted"}}
  end

  def render("cannot_delete_currently_used_interface.json", _assigns) do
    %{errors: %{detail: "Interface can't be deleted since it's currently used"}}
  end
end
