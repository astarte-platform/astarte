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

    result = AuthorizeFGA.call(resolution(%{}), relation: "viewer", target: :realm)

    assert %Absinthe.Resolution{errors: ["Unauthorized: Missing valid user session"]} = result
  end

  test "returns Unauthorized if there is no current_user in context" do
    # Authorization must be rejected before reaching the OpenFGA check.
    reject(&OpenFGA.check/4)

    result =
      AuthorizeFGA.call(resolution(%{realm_name: "testrealm"}),
        relation: "reader",
        target: :realm
      )

    assert %Absinthe.Resolution{errors: ["Unauthorized: Missing valid user session"]} = result
  end

  test "returns Unauthorized if there is no realm in context" do
    reject(&OpenFGA.check/4)

    result =
      AuthorizeFGA.call(resolution(%{current_user: %{id: "user1"}}),
        relation: "reader",
        target: :realm
      )

    assert %Absinthe.Resolution{errors: ["Unauthorized: Missing realm context"]} = result
  end

  test "returns Unauthorized if the user struct has no valid id or sub" do
    # A user with a nil id cannot be mapped to a stable user identifier, so the
    # middleware must return an Unauthorized error instead of falling back to
    # a fabricated identity.
    reject(&OpenFGA.check/4)

    context = %{realm_name: "testrealm", current_user: %{id: nil, authorizations: ["*:*:*"]}}

    result = AuthorizeFGA.call(resolution(context), relation: "device_register", target: :realm)

    assert %Absinthe.Resolution{errors: ["Unauthorized: Missing valid user session"]} = result
  end

  test "performs an OpenFGA check for the :realm target using the user's :id" do
    expect(OpenFGA, :check, fn "user:testrealm/testuser", "viewer", "realm:testrealm", [] ->
      :ok
    end)

    resolution = resolution(%{realm_name: "testrealm", current_user: %{id: "testuser"}})

    assert AuthorizeFGA.call(resolution, relation: "viewer", target: :realm) == resolution
  end

  test "sends the user's JWT roles as contextual tuples on the realm" do
    expect(OpenFGA, :check, fn "user:testrealm/user1", "viewer", "realm:testrealm", tuples ->
      assert tuples == [
               %{
                 user: "user:testrealm/user1",
                 relation: "fdo_manager",
                 object: "realm:testrealm"
               },
               %{
                 user: "user:testrealm/user1",
                 relation: "device_registrar",
                 object: "realm:testrealm"
               }
             ]

      :ok
    end)

    context = %{
      realm_name: "testrealm",
      current_user: %{id: "user1", roles: ["fdo_manager", "device_registrar"]}
    }

    resolution = resolution(context)

    assert AuthorizeFGA.call(resolution, relation: "viewer", target: :realm) == resolution
  end

  test "names the object from the hw_id argument for the :device target, placed in the realm" do
    expect(OpenFGA, :check, fn "user:testrealm/user1", "can_unregister", object, tuples ->
      assert object == "device:testrealm/my_device"

      assert tuples == [
               %{
                 user: "user:testrealm/user1",
                 relation: "fleet_manager",
                 object: "realm:testrealm"
               },
               %{user: "realm:testrealm", relation: "realm", object: "device:testrealm/my_device"}
             ]

      :ok
    end)

    context = %{realm_name: "testrealm", current_user: %{id: "user1", roles: ["fleet_manager"]}}
    resolution = resolution(context, %{hw_id: "my_device"})

    assert AuthorizeFGA.call(resolution, relation: "can_unregister", target: :device) ==
             resolution
  end

  test "names the object from the given argument for a {type, arg} target" do
    expect(OpenFGA, :check, fn "user:testrealm/user1",
                               "editor",
                               "interface:testrealm/com.Foo",
                               [%{user: "realm:testrealm", relation: "realm"}] ->
      :ok
    end)

    resolution =
      resolution(%{realm_name: "testrealm", current_user: %{id: "user1"}}, %{
        interface_name: "com.Foo"
      })

    opts = [relation: "editor", target: {:interface, :interface_name}]

    assert AuthorizeFGA.call(resolution, opts) == resolution
  end

  test "returns forbidden and logs a warning if an object-naming argument is missing or nil" do
    reject(&OpenFGA.check/4)

    for arguments <- [%{}, %{hw_id: nil}] do
      resolution =
        resolution(%{realm_name: "testrealm", current_user: %{id: "user1"}}, arguments)

      log =
        capture_log(fn ->
          result = AuthorizeFGA.call(resolution, relation: "editor", target: :device)

          assert %Absinthe.Resolution{
                   errors: ["Forbidden: OpenFGA denied access for this action"]
                 } = result
        end)

      assert log =~ "a :device-target field was called without hw_id"
    end
  end

  test "returns forbidden if the OpenFGA check denies access" do
    expect(OpenFGA, :check, fn _user, _relation, _object, _contextual_tuples ->
      {:error, :forbidden}
    end)

    resolution = resolution(%{realm_name: "testrealm", current_user: %{id: "user1"}})

    result = AuthorizeFGA.call(resolution, relation: "viewer", target: :realm)

    assert %Absinthe.Resolution{errors: ["Forbidden: OpenFGA denied access for this action"]} =
             result
  end

  test "returns internal error if the OpenFGA check itself fails" do
    expect(OpenFGA, :check, fn _user, _relation, _object, _contextual_tuples ->
      {:error, :nxdomain}
    end)

    resolution = resolution(%{realm_name: "testrealm", current_user: %{id: "user1"}})

    result = AuthorizeFGA.call(resolution, relation: "viewer", target: :realm)

    assert %Absinthe.Resolution{errors: ["Internal Server Error during authorization"]} = result
  end
end
