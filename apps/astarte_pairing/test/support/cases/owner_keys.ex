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

defmodule Astarte.Pairing.Cases.OwnerKeys do
  @moduledoc """
  Gives the realm of `Astarte.Pairing.Cases.Data`, which the test module must
  also use, a fixed set of owner keys shared by all of its tests: two ES256
  keys and one ES384 key.

  The context holds `:resolution` (an Absinthe resolution for the realm),
  `:namespace` (the ES256 keys' namespace) and `:expected_owner_keys` (the
  realm's key names, grouped by key algorithm).
  """

  use ExUnit.CaseTemplate

  import Astarte.Pairing.Helpers.FDO

  alias Astarte.Secrets

  setup_all %{realm_name: realm} do
    {:ok, es256} = Secrets.create_fdo_namespace(realm, :es256)
    {:ok, es384} = Secrets.create_fdo_namespace(realm, :es384)

    {:ok, _} = Secrets.create_keypair("owner_key_a", :es256, namespace: es256)
    {:ok, _} = Secrets.create_keypair("owner_key_b", :es256, namespace: es256)
    {:ok, _} = Secrets.create_keypair("owner_key_c", :es384, namespace: es384)

    on_exit(fn -> Enum.each([es256, es384], &delete_owner_keys/1) end)

    %{
      resolution: %{context: %{realm_name: realm}},
      namespace: es256,
      expected_owner_keys: %{
        es256: ["owner_key_a", "owner_key_b"],
        es384: ["owner_key_c"],
        rs256: [],
        rs384: []
      }
    }
  end
end
