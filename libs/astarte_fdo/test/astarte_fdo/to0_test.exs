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

defmodule Astarte.FDO.To0Test do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.FDO.Rendezvous
  alias Astarte.FDO.TO0
  alias COSE.Keys.ECC, as: Keys

  import Astarte.FDO.Helpers

  setup :verify_on_exit!

  describe "hello/0" do
    test "delegates to Rendezvous.send_hello/0 and returns its result" do
      nonce = :crypto.strong_rand_bytes(16)
      expected = {:ok, %{nonce: nonce, headers: []}}

      Rendezvous
      |> expect(:send_hello, fn -> expected end)

      assert ^expected = TO0.hello()
    end

    test "propagates :error from Rendezvous.send_hello/0" do
      Rendezvous
      |> expect(:send_hello, fn -> :error end)

      assert :error = TO0.hello()
    end
  end

  describe "owner_sign/5" do
    test "returns :ok when Rendezvous.register_ownership/2 returns {:ok, _}" do
      nonce = :crypto.strong_rand_bytes(16)
      ownership_voucher = sample_voucher()
      # TO1D signing hardcodes alg :es256, so we must use an EC256 key
      owner_key = Keys.generate(:es256)
      headers = [{"content-type", "application/cbor"}]

      Rendezvous
      |> expect(:register_ownership, fn _body, _headers -> {:ok, 3600} end)

      assert :ok = TO0.owner_sign("testrealm", nonce, ownership_voucher, owner_key, headers)
    end

    test "returns :error when Rendezvous.register_ownership/2 returns :error" do
      nonce = :crypto.strong_rand_bytes(16)
      ownership_voucher = sample_voucher()
      owner_key = Keys.generate(:es256)
      headers = []

      Rendezvous
      |> expect(:register_ownership, fn _body, _headers -> :error end)

      assert :error = TO0.owner_sign("testrealm", nonce, ownership_voucher, owner_key, headers)
    end
  end

  describe "claim_ownership_voucher/3" do
    test "returns :ok on successful hello and owner_sign" do
      nonce = :crypto.strong_rand_bytes(16)
      ownership_voucher = sample_voucher()
      owner_key = Keys.generate(:es256)

      Rendezvous
      |> expect(:send_hello, fn -> {:ok, %{nonce: nonce, headers: []}} end)
      |> expect(:register_ownership, fn _body, _headers -> {:ok, 3600} end)

      assert :ok = TO0.claim_ownership_voucher("testrealm", ownership_voucher, owner_key)
    end

    test "returns early with :error if hello fails" do
      ownership_voucher = sample_voucher()
      owner_key = Keys.generate(:es256)

      Rendezvous
      |> expect(:send_hello, fn -> :error end)

      assert :error = TO0.claim_ownership_voucher("testrealm", ownership_voucher, owner_key)
    end
  end
end
