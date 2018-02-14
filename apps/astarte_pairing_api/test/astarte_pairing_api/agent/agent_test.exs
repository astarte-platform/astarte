#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017 Ispirata Srl
#

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
