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

defmodule Astarte.Pairing.FDO.OpenBao.KeyTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.Pairing.FDO.OpenBao
  alias Astarte.Pairing.FDO.OpenBao.Key
  alias COSE.Keys
  alias COSE.Messages.Sign1

  setup context do
    realm_name = "realm#{System.unique_integer([:positive])}"
    key_name = "key#{System.unique_integer()}"
    key_algorithm = Map.get(context, :key_algorithm, :es256)
    {:ok, namespace} = OpenBao.create_namespace(realm_name, key_algorithm)
    {:ok, _} = OpenBao.create_keypair(key_name, key_algorithm, namespace: namespace)
    key = %Key{name: key_name, namespace: namespace, alg: key_algorithm}

    %{key: key}
  end

  test "can be used for Sign1 messages", %{key: key} do
    phdr = %{alg: key.alg}
    assert {:ok, _encoded} = Sign1.build(<<>>, phdr) |> Sign1.sign_encode_cbor(key)
  end

  describe "sign/3" do
    test "calls OpenBao.sign/5", %{key: key} do
      out = <<>>

      OpenBao
      |> expect(:sign, fn _key_name, _payload, _algorithm, _digest_type, _opts -> {:ok, out} end)

      assert {:ok, out} == Keys.sign(key, key.alg, <<>>)
    end

    test "returns `{:error, :signature_error}` in case of error", %{key: key} do
      OpenBao
      |> expect(:sign, fn _key_name, _payload, _algorithm, _digest_type, _opts -> :error end)

      assert {:error, :signature_error} == Keys.sign(key, key.alg, <<>>)
    end
  end

  test "verify/4 raises", %{key: key} do
    assert_raise RuntimeError, fn -> Keys.verify(key, :es256, <<>>, <<>>) end
  end
end
