#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.Cases.Data do
  @moduledoc """
  This module defines the setup for tests requiring access to the application
  database.

  You may define functions here to be used as helpers in your tests.
  """
  alias Astarte.Helpers.Triggers

  use ExUnit.CaseTemplate
  use Mimic
  import Astarte.Helpers.Database

  using opts do
    astarte_instance_id = Keyword.get_lazy(opts, :astarte_instance_id, &astarte_instance_id/0)
    realm_name = Keyword.get_lazy(opts, :realm_name, &realm_name/0)
    jwt_public_key = Keyword.get_lazy(opts, :jwt_public_key, &jwt_public_key_pem/0)

    quote do
      import Astarte.Cases.Data
      import Astarte.Helpers.Database

      @moduletag astarte_instance_id: unquote(astarte_instance_id)
      @moduletag realm_name: unquote(realm_name)
      # TODO: remove this when old test
      @moduletag realm: unquote(realm_name)
      @moduletag jwt_public_key: unquote(jwt_public_key)
    end
  end

  setup_all %{realm_name: realm, astarte_instance_id: astarte_instance_id, jwt_public_key: jwt} do
    setup_instance(astarte_instance_id, [realm], jwt)

    :ok
  end

  setup %{astarte_instance_id: astarte_instance_id} do
    setup_database_access(astarte_instance_id)
    Astarte.DataAccess.Config |> allow(self(), Triggers.rpc_trigger_client())

    :ok
  end

  def setup_instance(astarte_instance_id \\ nil, realm_names \\ nil, jwt \\ nil) do
    astarte_instance_id = astarte_instance_id || astarte_instance_id()
    realm_names = realm_names || [realm_name()]
    jwt_public_key = jwt || get_public_key()

    setup_database_access(astarte_instance_id)
    setup_astarte_keyspace()

    for realm_name <- realm_names do
      setup!(realm_name)
      insert_public_key!(realm_name, jwt_public_key)
    end

    on_exit(fn ->
      setup_database_access(astarte_instance_id)
      teardown_astarte_keyspace()

      for realm_name <- realm_names do
        teardown_realm_keyspace!(realm_name)
      end
    end)

    %{astarte_instance_id: astarte_instance_id, realm_names: realm_names}
  end

  defp astarte_instance_id, do: "test#{System.unique_integer([:positive])}"
  defp realm_name, do: "realm#{System.unique_integer([:positive])}"
  defp jwt_public_key_pem, do: get_public_key()
end
