#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.Auth.GraphQL.Middleware.AuthorizeFGATest do
  use ExUnit.Case, async: true
  use Mimic

  import ExUnit.CaptureLog

  alias Astarte.Auth.GraphQL.Middleware.AuthorizeFGA
  alias Astarte.Auth.OpenFGA

  defp resolution(context, arguments \\ %{}) do
    %Absinthe.Resolution{context: context, arguments: arguments}
  end

  test "fails closed on an empty context" do
    reject(&OpenFGA.check/4)

    result = AuthorizeFGA.call(resolution(%{}), relation: "can_read_realm", target: :realm)

    assert %Absinthe.Resolution{errors: ["Unauthorized: Missing valid user session"]} = result
  end

  test "returns Unauthorized if there is no current_user in context" do
    # Authorization must be rejected before reaching the OpenFGA check.
    reject(&OpenFGA.check/4)

    result =
      AuthorizeFGA.call(resolution(%{realm_name: "testrealm"}),
        relation: "can_read_realm",
        target: :realm
      )

    assert %Absinthe.Resolution{errors: ["Unauthorized: Missing valid user session"]} = result
  end

  test "returns Unauthorized if there is no realm in context" do
    reject(&OpenFGA.check/4)

    result =
      AuthorizeFGA.call(resolution(%{current_user: %{id: "user1"}}),
        relation: "can_read_realm",
        target: :realm
      )

    assert %Absinthe.Resolution{errors: ["Unauthorized: Missing realm context"]} = result
  end

  test "returns Unauthorized if the user struct has no valid id or sub" do
    reject(&OpenFGA.check/4)

    context = %{realm_name: "testrealm", current_user: %{id: nil, authorizations: ["*:*:*"]}}

    result =
      AuthorizeFGA.call(resolution(context), relation: "can_register_device", target: :realm)

    assert %Absinthe.Resolution{errors: ["Unauthorized: Missing valid user session"]} = result
  end

  test "returns forbidden and logs a warning if an object-naming argument is missing or nil" do
    reject(&OpenFGA.check/4)

    for arguments <- [%{}, %{hw_id: nil}] do
      resolution =
        resolution(%{realm_name: "testrealm", current_user: %{id: "user1"}}, arguments)

      log =
        capture_log(fn ->
          result = AuthorizeFGA.call(resolution, relation: "can_update", target: :device)

          assert %Absinthe.Resolution{
                   errors: ["Forbidden: OpenFGA denied access for this action"]
                 } = result
        end)

      assert log =~ "a :device-target field was called without hw_id"
    end
  end

  test "rejects a sub OpenFGA can't use without calling it, and warns about it" do
    reject(&OpenFGA.check/4)

    for sub <- ["a b", "a#b", "a:b", "a\n", "", String.duplicate("a", 512), 42] do
      resolution = resolution(%{realm_name: "testrealm", current_user: %{id: sub}})

      log =
        capture_log(fn ->
          result = AuthorizeFGA.call(resolution, relation: "can_read_realm", target: :realm)

          assert %Absinthe.Resolution{errors: ["Unauthorized: invalid user identity"]} = result
        end)

      assert log =~ "has an invalid sub"
    end
  end

  test "rejects an invalid hw_id without calling OpenFGA, or warning about it" do
    reject(&OpenFGA.check/4)

    extended_id = Base.url_encode64(:binary.copy(<<0>>, 17), padding: false)

    for hw_id <- ["a b", "a#b", "not-a-device-id", extended_id] do
      context = %{realm_name: "testrealm", current_user: %{id: "user1"}}
      resolution = resolution(context, %{hw_id: hw_id})

      log =
        capture_log([level: :warning], fn ->
          result = AuthorizeFGA.call(resolution, relation: "can_unregister", target: :device)

          assert %Absinthe.Resolution{errors: ["Invalid argument: hw_id"]} = result
        end)

      refute log =~ "invalid hw_id"
    end
  end

  test "rejects an invalid object name without calling OpenFGA" do
    reject(&OpenFGA.check/4)

    opts = [relation: "can_read", target: {:interface, :interface_name}]

    for name <- ["a b", "a#b", "a:b", String.duplicate("a", 256)] do
      context = %{realm_name: "testrealm", current_user: %{id: "user1"}}
      resolution = resolution(context, %{interface_name: name})

      assert %Absinthe.Resolution{errors: ["Invalid argument: interface_name"]} =
               AuthorizeFGA.call(resolution, opts)
    end
  end

  test "returns internal error if the OpenFGA check itself fails" do
    expect(OpenFGA, :check, fn _user, _relation, _object, _contextual_tuples ->
      {:error, :nxdomain}
    end)

    resolution = resolution(%{realm_name: "testrealm", current_user: %{id: "user1"}})

    result = AuthorizeFGA.call(resolution, relation: "can_read_realm", target: :realm)

    assert %Absinthe.Resolution{errors: ["Internal Server Error during authorization"]} = result
  end
end
