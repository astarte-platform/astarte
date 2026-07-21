defmodule Astarte.PairingWeb.GraphQL.Middleware.AuthorizeFGATest do
  use ExUnit.Case
  use Mimic

  alias Astarte.PairingWeb.GraphQL.Middleware.AuthorizeFGA
  alias Astarte.Pairing.Auth.User
  alias Astarte.Pairing.Config

  setup do
    # Clear cache before each test
    :persistent_term.erase(:openfga_store_id)
    System.delete_env("ASTARTE_PAIRING_OPENFGA_STORE_ID")

    # Stub default config
    stub(Config, :authentication_disabled?, fn -> false end)

    :ok
  end

  test "bypasses authorization if authentication_disabled? is true" do
    expect(Config, :authentication_disabled?, fn -> true end)

    resolution = %Absinthe.Resolution{context: %{}}
    assert AuthorizeFGA.call(resolution, []) == resolution
  end

  test "falls back to legacy auth if no store ID is set and /stores is empty" do
    # Mock HTTPoison to return no stores
    expect(HTTPoison, :get, fn url ->
      assert url =~ "/stores"
      {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(%{"stores" => []})}}
    end)

    resolution = %Absinthe.Resolution{
      context: %{
        realm_name: "testrealm",
        current_user: %{authorizations: ["GET::testpath"]}
      }
    }

    opts = [
      relation: "reader",
      target: :realm,
      legacy_method: "GET",
      legacy_path: "testpath"
    ]

    # Legacy auth should succeed
    assert AuthorizeFGA.call(resolution, opts) == resolution
  end

  test "fails legacy auth if context is invalid and no store ID" do
    expect(HTTPoison, :get, fn _url ->
      {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(%{"stores" => []})}}
    end)

    resolution = %Absinthe.Resolution{context: %{}}

    opts = [
      relation: "reader",
      target: :realm,
      legacy_method: "GET",
      legacy_path: "testpath"
    ]

    result = AuthorizeFGA.call(resolution, opts)

    assert %Absinthe.Resolution{
             errors: ["Unauthorized: Missing realm. Provide the 'astarte-realm' header."]
           } = result
  end

  test "fetches store ID from /stores if not in ENV and caches it" do
    System.delete_env("ASTARTE_PAIRING_OPENFGA_STORE_ID")

    expect(HTTPoison, :get, fn url ->
      assert url =~ "/stores"

      {:ok,
       %HTTPoison.Response{
         status_code: 200,
         body: Jason.encode!(%{"stores" => [%{"id" => "fetched_id"}]})
       }}
    end)

    expect(HTTPoison, :post, fn url, body, _headers ->
      assert url =~ "/stores/fetched_id/check"

      decoded = Jason.decode!(body)
      assert decoded["tuple_key"]["user"] == "user:testuser"
      assert decoded["tuple_key"]["relation"] == "viewer"
      assert decoded["tuple_key"]["object"] == "realm:testrealm"

      {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(%{"allowed" => true})}}
    end)

    resolution = %Absinthe.Resolution{
      context: %{
        realm_name: "testrealm",
        current_user: %{id: "testuser"}
      }
    }

    opts = [relation: "viewer", target: :realm]

    # First call will trigger HTTPoison.get
    assert AuthorizeFGA.call(resolution, opts) == resolution

    # Second call should use cache, so HTTPoison.get shouldn't be called again
    # (Mimic expect(..., :get) expects exactly 1 call since we didn't specify count, so a second call would crash)
    expect(HTTPoison, :post, fn url, _body, _headers ->
      assert url =~ "/stores/fetched_id/check"
      {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(%{"allowed" => true})}}
    end)

    assert AuthorizeFGA.call(resolution, opts) == resolution
  end

  test "uses ASTARTE_PAIRING_OPENFGA_STORE_ID if set in ENV" do
    System.put_env("ASTARTE_PAIRING_OPENFGA_STORE_ID", "env_store_id")

    # HTTPoison.get should NOT be called

    expect(HTTPoison, :post, fn url, _body, _headers ->
      assert url =~ "/stores/env_store_id/check"
      {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(%{"allowed" => true})}}
    end)

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
    System.put_env("ASTARTE_PAIRING_OPENFGA_STORE_ID", "store123")

    expect(HTTPoison, :post, fn _url, body, _headers ->
      decoded = Jason.decode!(body)
      assert decoded["tuple_key"]["object"] == "device:my_device"
      {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(%{"allowed" => true})}}
    end)

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

  test "returns forbidden if OpenFGA check returns allowed=false" do
    System.put_env("ASTARTE_PAIRING_OPENFGA_STORE_ID", "store123")

    expect(HTTPoison, :post, fn _url, _body, _headers ->
      {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(%{"allowed" => false})}}
    end)

    resolution = %Absinthe.Resolution{
      context: %{realm_name: "testrealm", current_user: %{id: "user1"}}
    }

    opts = [relation: "viewer", target: :realm]

    result = AuthorizeFGA.call(resolution, opts)

    assert %Absinthe.Resolution{errors: ["Forbidden: OpenFGA denied access for this action"]} =
             result
  end

  test "returns internal error if OpenFGA check HTTP request fails" do
    System.put_env("ASTARTE_PAIRING_OPENFGA_STORE_ID", "store123")

    expect(HTTPoison, :post, fn _url, _body, _headers ->
      {:error, %HTTPoison.Error{reason: :nxdomain}}
    end)

    resolution = %Absinthe.Resolution{
      context: %{realm_name: "testrealm", current_user: %{id: "user1"}}
    }

    opts = [relation: "viewer", target: :realm]

    result = AuthorizeFGA.call(resolution, opts)
    assert %Absinthe.Resolution{errors: ["Internal Server Error during authorization"]} = result
  end

  test "returns Unauthorized if user struct has no valid id or sub" do
    System.put_env("ASTARTE_PAIRING_OPENFGA_STORE_ID", "store123")

    # No HTTPoison call should be made — authorization must be rejected
    # before reaching the OpenFGA check endpoint.

    # A %User{id: nil} cannot be mapped to a stable user identifier, so the
    # middleware must return an Unauthorized error instead of falling back to
    # a fabricated "generic_agent" identity.
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
end
