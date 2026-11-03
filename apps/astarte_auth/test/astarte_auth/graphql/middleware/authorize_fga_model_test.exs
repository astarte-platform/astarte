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

defmodule Astarte.Auth.GraphQL.Middleware.AuthorizeFGAModelTest do
  use Astarte.Auth.Cases.AuthorizationModel, async: true

  import ExUnit.CaptureLog

  alias Astarte.Auth.GraphQL.Middleware.AuthorizeFGA

  @hw_id "f0VMRgIBAQAAAAAAAAAAAA"
  @same_device_hw_id "f0VMRgIBAQAAAAAAAAAAAB"
  @forbidden "Forbidden: OpenFGA denied access for this action"

  setup_all %{store_id: store_id} do
    write_tuples!(store_id, [
      %{user: "user:otherrealm/other_realm_admin", relation: "admin", object: "realm:otherrealm"},
      %{
        user: "user:testrealm/device_manager",
        relation: "fleet_manager",
        object: "device:testrealm/#{@hw_id}"
      }
    ])
  end

  defp errors(user, opts, arguments \\ %{}, realm_name \\ "testrealm") do
    context = %{realm_name: realm_name, current_user: user}
    resolution = %Absinthe.Resolution{context: context, arguments: arguments}

    AuthorizeFGA.call(resolution, opts).errors
  end

  test "a role from the token grants the capabilities it implies" do
    user = %{id: "token_user", roles: ["fdo_manager"]}

    assert errors(user, relation: "can_manage_fdo", target: :realm) == []
    assert errors(user, relation: "can_read_fdo", target: :realm) == []
  end

  test "a token without roles grants nothing" do
    user = %{id: "token_user", roles: []}

    assert errors(user, relation: "can_read_fdo", target: :realm) == [@forbidden]
  end

  test "a role doesn't grant more than the model says" do
    user = %{id: "token_user", roles: ["fdo_viewer"]}

    assert errors(user, relation: "can_read_fdo", target: :realm) == []
    assert errors(user, relation: "can_manage_fdo", target: :realm) == [@forbidden]
  end

  test "a realm role reaches the realm's devices" do
    opts = [relation: "can_unregister", target: :device]
    arguments = %{hw_id: @hw_id}

    assert errors(%{id: "token_user", roles: ["fleet_manager"]}, opts, arguments) == []
    assert errors(%{id: "token_user", roles: ["observer"]}, opts, arguments) == [@forbidden]
  end

  test "equivalent encodings of a hw_id name the same device" do
    user = %{id: "device_manager", roles: []}
    opts = [relation: "can_unregister", target: :device]

    assert errors(user, opts, %{hw_id: @hw_id}) == []
    assert errors(user, opts, %{hw_id: @same_device_hw_id}) == []
  end

  test "a realm role reaches the object named by a {type, arg} target" do
    opts = [relation: "can_read_data", target: {:interface, :interface_name}]
    arguments = %{interface_name: "com.my.Commands"}

    assert errors(%{id: "token_user", roles: ["data_writer"]}, opts, arguments) == []
    assert errors(%{id: "token_user", roles: ["fleet_manager"]}, opts, arguments) == [@forbidden]
  end

  test "roles the model doesn't know don't take away the access a valid one gives" do
    user = %{id: "token_user", roles: ["fdo_manager", "offline_access", 1, "parent"]}

    assert errors(user, relation: "can_read_fdo", target: :realm) == []
  end

  test "roles the model doesn't know grant nothing" do
    user = %{id: "token_user", roles: ["offline_access"]}

    assert errors(user, relation: "can_read_fdo", target: :realm) == [@forbidden]
  end

  test "a roles claim that is not a list grants nothing" do
    user = %{id: "token_user", roles: "fdo_manager"}

    assert errors(user, relation: "can_read_fdo", target: :realm) == [@forbidden]
  end

  test "logs the roles it ignores at debug level" do
    user = %{id: "token_user", roles: ["fdo_viewer", "ignored_by_the_model"]}
    opts = [relation: "can_read_fdo", target: :realm]

    assert capture_log([level: :debug], fn -> errors(user, opts) end) =~ "ignored_by_the_model"
    refute capture_log([level: :info], fn -> errors(user, opts) end) =~ "ignored_by_the_model"
  end

  test "a grant in one realm doesn't count in another" do
    user = %{id: "other_realm_admin", roles: []}
    opts = [relation: "can_read_realm", target: :realm]

    assert errors(user, opts, %{}, "otherrealm") == []
    assert errors(user, opts, %{}, "testrealm") == [@forbidden]
  end

  test "accepts the subs identity providers commonly use" do
    for sub <- ["a.b+c@example.com", "auth0|123", "123e4567-e89b-12d3-a456-426614174000"] do
      user = %{id: sub, roles: ["fdo_viewer"]}

      assert errors(user, relation: "can_read_fdo", target: :realm) == []
    end
  end
end
