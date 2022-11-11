#
# This file is part of Astarte.
#
# Copyright 2021 Ispirata Srl
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

defmodule Astarte.RealmManagement.API.Triggers.Policies.PolicyTest do
  use Astarte.RealmManagement.API.DataCase

  alias Astarte.RealmManagement.API.Triggers.Policies
  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.Policy.Handler
  alias Astarte.Core.Triggers.Policy.ErrorKeyword
  @realm "testrealm"
  @policy_name "aname"
  @valid_attrs %{
    name: @policy_name,
    maximum_capacity: 300,
    retry_times: 10,
    event_ttl: 10,
    error_handlers: [
      %{on: "any_error", strategy: "retry"}
    ]
  }
  @invalid_attrs %{
    "name" => "pippo",
    "maximum_capacity" => 100
  }

  test "install, list, source and delete succeed with valid attrs" do
    assert {:ok, %Policy{} = policy} = Policies.create_trigger_policy(@realm, @valid_attrs)

    assert %Policy{
             name: @policy_name,
             maximum_capacity: 300,
             retry_times: 10,
             event_ttl: 10,
             error_handlers: [handler]
           } = policy

    assert %Handler{
             on: %ErrorKeyword{keyword: "any_error"},
             strategy: "retry"
           } = handler

    assert [@policy_name] = Policies.list_trigger_policies(@realm)

    assert {:ok, json} = Policies.get_trigger_policy_source(@realm, @policy_name)
    assert {:ok, %{name: @policy_name}} = Jason.decode(json, keys: :atoms)

    assert {:error, :trigger_policy_already_present} =
             Policies.create_trigger_policy(@realm, @valid_attrs)

    assert :ok = Policies.delete_trigger_policy(@realm, @policy_name)

    assert {:ok, %Policy{} = policy} = Policies.create_trigger_policy(@realm, @valid_attrs)
  end

  test "install fails with invalid attrs" do
    assert {:error, %Ecto.Changeset{errors: _}} =
             Policies.create_trigger_policy(@realm, @invalid_attrs)
  end

  test "delete fails when policy is not installed" do
    assert {:error, :trigger_policy_not_found} = Policies.delete_trigger_policy(@realm, "pippo")
  end

  test "source fails when policy is not installed" do
    assert {:error, :trigger_policy_not_found} =
             Policies.get_trigger_policy_source(@realm, "pippo")
  end
end
