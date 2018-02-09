defmodule Astarte.Pairing.API.AgentTest do
  use Astarte.Pairing.API.DataCase

  alias Astarte.Pairing.API.Agent
  alias Astarte.Pairing.Mock

  describe "api_keys" do
    alias Astarte.Pairing.API.Agent.APIKey

    @test_realm "testrealm"
    @test_hw_id "PDL3KNj7RVifHZD-1w_6wA"

    @valid_attrs %{"realm" => @test_realm, "hw_id" => @test_hw_id}
    @no_hw_id_attrs %{"realm" => @test_realm}
    @empty_realm_attrs %{"realm" => nil, "hw_id" => @test_hw_id}
    @existing_hw_id_attrs %{"realm" => @test_realm, "hw_id" => Mock.existing_hw_id()}

    test "generate_api_key/1 with valid data generates an api_key" do
      assert {:ok, %APIKey{api_key: api_key}} = Agent.generate_api_key(@valid_attrs)
      assert api_key == Mock.api_key(@test_realm, @test_hw_id)
    end

    test "generate_api_key/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Agent.generate_api_key(@no_hw_id_attrs)
      assert {:error, %Ecto.Changeset{}} = Agent.generate_api_key(@empty_realm_attrs)
    end

    test "generate_api_key/1 with existing hw_id data returns error" do
      assert {:error, %Ecto.Changeset{}} = Agent.generate_api_key(@existing_hw_id_attrs)
    end
  end
end
