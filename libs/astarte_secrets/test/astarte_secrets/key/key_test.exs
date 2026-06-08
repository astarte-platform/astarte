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

defmodule Astarte.Secrets.KeyTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.Secrets
  alias Astarte.Secrets.Core
  alias Astarte.Secrets.Key
  alias COSE.Keys
  alias COSE.Messages.Sign1

  import Astarte.Helpers.Key

  setup :key_setup

  test "can be used for Sign1 messages", %{key: key} do
    phdr = %{alg: key.alg}
    assert {:ok, _encoded} = Sign1.build(<<>>, phdr) |> Sign1.sign_encode_cbor(key)
  end

  describe "sign/3" do
    test "calls Secrets.sign/5", %{key: key} do
      out = <<>>

      Secrets
      |> expect(:sign, fn _key_name, _payload, _algorithm, _digest_type, _opts -> {:ok, out} end)

      assert {:ok, out} == Keys.sign(key, key.alg, <<>>)
    end

    test "returns `{:error, :signature_error}` in case of error", %{key: key} do
      Secrets
      |> expect(:sign, fn _key_name, _payload, _algorithm, _digest_type, _opts -> :error end)

      assert {:error, :signature_error} == Keys.sign(key, key.alg, <<>>)
    end
  end

  test "verify/4 raises", %{key: key} do
    assert_raise RuntimeError, fn -> Keys.verify(key, :es256, <<>>, <<>>) end
  end

  test "uses the numerically largest (not alphabetically largest) revision for the public key",
       %{key: key} do
    for _ <- 0..9 do
      {:ok, _} = Secrets.rotate(key.name, key.namespace)
    end

    {:ok, resp} = Core.get_key(key.name, key.namespace)
    {:ok, data} = Core.parse_json_data(resp)
    assert {:ok, key} = Key.parse(key.name, key.namespace, data)

    {_rev, last_revision} =
      data["keys"]
      |> Enum.max_by(fn {rev, _} -> String.to_integer(rev) end)

    expected_pem = last_revision["public_key"]
    assert key.public_pem == expected_pem
  end

  test "changeset/2 does not include the pem for invalid changesets" do
    # does not have required params
    invalid_params = %{}
    result = Key.changeset(%Key{}, invalid_params)
    refute result.valid?
    refute Map.has_key?(result.changes, :public_pem)
  end
end
