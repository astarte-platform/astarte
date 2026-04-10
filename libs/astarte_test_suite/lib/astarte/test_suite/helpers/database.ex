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

defmodule Astarte.TestSuite.Helpers.Database do
  @moduledoc false

  alias Astarte.TestSuite.CaseContext

  def connect(context) do
    context
    |> CaseContext.require_keys!([:common_realm_ready?], :database_connect)
    |> CaseContext.put_fixture(:database_connect, %{database_connected?: true})
  end

  def keyspace(context) do
    context
    |> CaseContext.require_keys!([:database_connected?], :database_keyspace)
    |> CaseContext.put_fixture(:database_keyspace, %{database_keyspace_ready?: true})
  end

  def setup(context) do
    context
    |> CaseContext.require_keys!([:database_keyspace_ready?], :database_setup)
    |> CaseContext.put_fixture(:database_setup, %{database_schema_ready?: true})
  end

  def setup_auth(context) do
    context
    |> CaseContext.require_keys!([:database_schema_ready?], :database_setup_auth)
    |> CaseContext.put_fixture(:database_setup_auth, %{database_auth_ready?: true})
  end
end
