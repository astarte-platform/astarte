defmodule Astarte.PairingWeb.GraphQL.Middleware.AuthorizeFGATest do
  use ExUnit.Case
  use Mimic

  alias Astarte.Pairing.Config
  alias Astarte.Pairing.OpenFGA
  alias Astarte.PairingWeb.GraphQL.Middleware.AuthorizeFGA

  setup do
    stub(Config, :authentication_disabled?, fn -> false end)

    :ok
  end

  test "bypasses authorization if authentication_disabled? is true" do
    expect(Config, :authentication_disabled?, fn -> true end)

    resolution = %Absinthe.Resolution{context: %{}}
    assert AuthorizeFGA.call(resolution, []) == resolution
  end

  test "returns Unauthorized if there is no current_user in context" do
    # Authorization must be rejected before reaching the OpenFGA check.
    resolution = %Absinthe.Resolution{context: %{realm_name: "testrealm"}}

    opts = [relation: "reader", target: :realm]

    result = AuthorizeFGA.call(resolution, opts)

    assert %Absinthe.Resolution{
             errors: ["Unauthorized: Missing valid user session"]
           } = result
  end

  test "returns Unauthorized if there is no realm in context" do
    resolution = %Absinthe.Resolution{context: %{current_user: %{id: "user1"}}}

    opts = [relation: "reader", target: :realm]

    result = AuthorizeFGA.call(resolution, opts)

    assert %Absinthe.Resolution{
             errors: ["Unauthorized: Missing realm context"]
           } = result
  end

  test "returns Unauthorized if user struct has no valid id or sub" do
    # A %User{id: nil} cannot be mapped to a stable user identifier, so the
    # middleware must return an Unauthorized error instead of falling back to
    # a fabricated identity.
    resolution = %Absinthe.Resolution{
      context: %{
        realm_name: "testrealm",
        current_user: %Astarte.Pairing.Auth.User{id: nil, authorizations: ["*:*:*"]}
      }
    }

    opts = [relation: "device_register", target: :realm]

    result = AuthorizeFGA.call(resolution, opts)

    assert %Absinthe.Resolution{
             errors: ["Unauthorized: Missing valid user session"]
           } = result
  end

  test "performs an OpenFGA check for the :realm target using the user's :id" do
    expect(OpenFGA, :check, fn "user:testuser", "viewer", "realm:testrealm" -> :ok end)

    resolution = %Absinthe.Resolution{
      context: %{
        realm_name: "testrealm",
        current_user: %{id: "testuser"}
      }
    }

    opts = [relation: "viewer", target: :realm]

    assert AuthorizeFGA.call(resolution, opts) == resolution
  end

  test "performs an OpenFGA check using the \"sub\" claim if :id is not available" do
    expect(OpenFGA, :check, fn "user:test_sub", "viewer", "realm:testrealm" -> :ok end)

    resolution = %Absinthe.Resolution{
      context: %{
        realm_name: "testrealm",
        current_user: %{"sub" => "test_sub"}
      }
    }

    opts = [relation: "viewer", target: :realm]

    assert AuthorizeFGA.call(resolution, opts) == resolution
  end

  test "formats object correctly for :device target" do
    expect(OpenFGA, :check, fn "user:user1", "editor", "device:my_device" -> :ok end)

    resolution = %Absinthe.Resolution{
      context: %{
        realm_name: "testrealm",
        current_user: %{id: "user1"}
      },
      arguments: %{hw_id: "my_device"}
    }

    opts = [relation: "editor", target: :device]

    assert AuthorizeFGA.call(resolution, opts) == resolution
  end

  test "returns forbidden if OpenFGA check returns forbidden" do
    expect(OpenFGA, :check, fn _user, _relation, _object -> {:error, :forbidden} end)

    resolution = %Absinthe.Resolution{
      context: %{realm_name: "testrealm", current_user: %{id: "user1"}}
    }

    opts = [relation: "viewer", target: :realm]

    result = AuthorizeFGA.call(resolution, opts)

    assert %Absinthe.Resolution{errors: ["Forbidden: OpenFGA denied access for this action"]} =
             result
  end

  test "returns internal error if the OpenFGA check fails" do
    expect(OpenFGA, :check, fn _user, _relation, _object -> {:error, :nxdomain} end)

    resolution = %Absinthe.Resolution{
      context: %{realm_name: "testrealm", current_user: %{id: "user1"}}
    }

    opts = [relation: "viewer", target: :realm]

    result = AuthorizeFGA.call(resolution, opts)
    assert %Absinthe.Resolution{errors: ["Internal Server Error during authorization"]} = result
  end
end
