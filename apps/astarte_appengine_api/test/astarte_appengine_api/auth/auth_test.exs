defmodule Astarte.AppEngine.API.Auth.AuthTest do
  use Astarte.Cases.Data, async: true
  use Mimic

  alias Astarte.AppEngine.API.Auth
  alias Astarte.DataAccess.Repo

  describe "fetch_public_key/1" do
    test "returns {:ok, pem} when public key is found", %{realm_name: realm_name} do
      assert {:ok, _} = Auth.fetch_public_key(realm_name)
    end

    test "returns {:error, :public_key_not_found} when no key is found", %{realm_name: realm_name} do
      Mimic.stub(Repo, :safe_fetch_one, fn _query, _opts ->
        {:error, :public_key_not_found}
      end)

      assert {:error, :public_key_not_found} == Auth.fetch_public_key(realm_name)
    end

    test "returns {:error, :realm_not_found} when realm is not found" do
      assert {:error, :realm_not_found} == Auth.fetch_public_key("testrealm")
    end

    test "returns {:error, error} for other errors" do
      Mimic.stub(Repo, :safe_fetch_one, fn _query, _opts ->
        {:error, :database_error}
      end)

      assert {:error, :database_error} == Auth.fetch_public_key("testrealm")
    end
  end
end
