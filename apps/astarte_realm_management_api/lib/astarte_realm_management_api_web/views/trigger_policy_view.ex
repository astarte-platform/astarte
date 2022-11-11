#
# This file is part of Astarte.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Astarte.RealmManagement.APIWeb.TriggerPolicyView do
  use Astarte.RealmManagement.APIWeb, :view
  alias Astarte.RealmManagement.APIWeb.TriggerPolicyView

  def render("index.json", %{policies: policies}) do
    %{data: render_many(policies, TriggerPolicyView, "trigger_policy_name_only.json")}
  end

  def render("show.json", %{policy: policy}) do
    %{data: render_one(policy, TriggerPolicyView, "policy.json")}
  end

  def render("already_installed_policy.json", _assigns) do
    %{errors: %{detail: "Policy already exists"}}
  end

  def render("policy.json", %{trigger_policy: policy}) do
    policy
  end

  def render("trigger_policy_name_only.json", %{trigger_policy: policy_name}) do
    policy_name
  end
end
