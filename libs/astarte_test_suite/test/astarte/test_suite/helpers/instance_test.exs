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

defmodule Astarte.TestSuite.Helpers.InstanceTest do
  use ExUnit.Case, async: true

  alias Astarte.TestSuite.Helpers.Instance, as: InstanceHelper

  test "instance helper sets setup flag" do
    assert setup_context().instance_setup?
  end

  @tag :real_db
  test "instance helper sets database flag" do
    assert context().instance_database_ready?
  end

  @tag :real_db
  test "instance helper creates one keyspace per instance" do
    assert context().instance_keyspaces |> length() == 2
  end

  @tag :real_db
  test "instance helper creates keyspace statements for each instance" do
    assert context().instance_database_statements |> length() == 4
  end

  @tag :real_db
  test "instance helper creates astarte keyspace SQL" do
    context = context()

    assert context.instance_database_statements |> hd() =~
             "CREATE KEYSPACE IF NOT EXISTS #{hd(context.instance_keyspaces)}"
  end

  @tag :real_db
  test "instance helper creates realms table SQL" do
    context = context()

    assert Enum.at(context.instance_database_statements, 1) =~
             "CREATE TABLE IF NOT EXISTS #{hd(context.instance_keyspaces)}.realms"
  end

  defp setup_context do
    [first_instance, second_instance] = unique_instance_names()

    %{
      instance_cluster: :xandra,
      instances: %{
        first_instance => {first_instance, nil},
        second_instance => {second_instance, nil}
      }
    }
    |> InstanceHelper.setup()
  end

  defp context do
    setup_context()
    |> InstanceHelper.data()
  end

  defp unique_instance_names do
    [
      "astarte" <> Integer.to_string(System.unique_integer([:positive])),
      "astarte" <> Integer.to_string(System.unique_integer([:positive]))
    ]
  end
end
