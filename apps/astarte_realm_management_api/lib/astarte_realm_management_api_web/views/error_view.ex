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

defmodule Astarte.RealmManagement.APIWeb.ErrorView do
  use Astarte.RealmManagement.APIWeb, :view

  def render("404.json", _assigns) do
    %{errors: %{detail: "Not found"}}
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

  def render("interface_not_found.json", _assigns) do
    %{errors: %{detail: "Interface not found"}}
  end

  def render("invalid_major.json", _assigns) do
    %{errors: %{detail: "Invalid major version"}}
  end

  def render("trigger_not_found.json", _assigns) do
    %{errors: %{detail: "Trigger not found"}}
  end

  def render("trigger_policy_not_found.json", _assigns) do
    %{errors: %{detail: "Trigger policy not found"}}
  end

  def render("trigger_policy_already_present.json", _assigns) do
    %{errors: %{detail: "Policy already exists"}}
  end

  def render("cannot_delete_currently_used_trigger_policy.json", _assigns) do
    %{errors: %{detail: "Cannot delete policy as it is being currently used by triggers"}}
  end

  def render("trigger_policy_prefetch_count_not_allowed.json", _assigns) do
    %{errors: %{detail: "Not allowed to specify prefetch_count in policy"}}
  end

  def render("overlapping_mappings.json", _assigns) do
    %{errors: %{detail: "Overlapping endpoints in interface mappings"}}
  end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def template_not_found(_template, assigns) do
    render("500.json", assigns)
  end
end
