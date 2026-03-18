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

defmodule Astarte.Pairing.FDO.OpenBaoTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.Pairing.FDO.OpenBao
  alias Astarte.Pairing.FDO.OpenBao.Core

  import Astarte.Helpers.OpenBao

  describe "create_namespace/3" do
    setup :namespace_tokens_setup

    test "calls core functions", context do
      %{realm_name: realm_name, user_id: user_id, key_algorithm: key_algorithm} = context

      ref = System.unique_integer()

      Core
      |> expect(:namespace_tokens, fn ^realm_name, ^user_id, ^key_algorithm -> ref end)
      |> expect(:create_nested_namespace, fn ^ref -> {:ok, ""} end)

      assert {:ok, _} = OpenBao.create_namespace(realm_name, user_id, key_algorithm)
    end
  end
end
