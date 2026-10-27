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

defmodule Astarte.TestSuite.Cases.AuthConnTest do
  use ExUnit.Case, async: true

  alias Astarte.TestSuite.Cases.AuthConn, as: AuthConnCase

  test "requires auth_conn configuration" do
    assert_raise ArgumentError, ~r/:auth_conn requires :jwt to be configured/, fn ->
      AuthConnCase.normalize_config!([])
    end
  end

  test "requires the auth_conn claim configuration" do
    assert_raise ArgumentError, ~r/:auth_conn requires :claim to be configured/, fn ->
      AuthConnCase.normalize_config!(jwt: "token")
    end
  end

  test "normalizes auth_conn configuration" do
    assert AuthConnCase.normalize_config!(jwt: "token", claim: %{scope: "realm"}) == %{
             jwt: "token",
             claim: %{scope: "realm"}
           }
  end

  test "rejects an invalid auth_conn jwt" do
    assert_raise ArgumentError, ~r/:auth_conn expects :jwt to be a binary/, fn ->
      AuthConnCase.normalize_config!(jwt: 1, claim: %{})
    end
  end

  test "rejects an invalid auth_conn claim" do
    assert_raise ArgumentError, ~r/:auth_conn expects :claim to be a map/, fn ->
      AuthConnCase.normalize_config!(jwt: "token", claim: "realm")
    end
  end

  test "keeps an explicit nil auth_conn configuration" do
    assert AuthConnCase.normalize_config!(jwt: nil, claim: nil) == %{
             jwt: nil,
             claim: nil
           }
  end

  test "rejects removed auth_conn configuration" do
    assert_raise ArgumentError, ~r/unknown configuration keys/, fn ->
      AuthConnCase.normalize_config!(token_ttl: 60)
    end
  end
end
