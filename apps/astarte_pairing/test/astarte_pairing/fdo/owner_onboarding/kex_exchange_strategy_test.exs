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
defmodule Astarte.Pairing.FDO.OwnerOnboarding.KeyExchangeStrategyTest do
  use ExUnit.Case, async: true

  alias Astarte.Pairing.FDO.OwnerOnboarding.KeyExchangeStrategy
  alias COSE.Keys.ECC
  alias COSE.Keys.RSA

  describe "validate/2" do
    test "validates device requesting DHKEXid14 when Owner Key is of type RSA2048" do
      owner_key = %RSA{alg: :rs256}
      assert :ok = KeyExchangeStrategy.validate("DHKEXid14", owner_key)
    end

    test "validates device requesting DHKEXid15 when Owner Key is of type RSA3072" do
      owner_key = %RSA{alg: :rs384}
      assert :ok = KeyExchangeStrategy.validate("DHKEXid15", owner_key)
    end

    test "validates ECDH256 successfully when Owner uses P-256" do
      owner_key = %ECC{crv: :p256}
      assert :ok = KeyExchangeStrategy.validate("ECDH256", owner_key)
    end

    test "validates ECDH384 successfully when Owner uses P-384" do
      owner_key = %ECC{crv: :p384}
      assert :ok = KeyExchangeStrategy.validate("ECDH384", owner_key)
    end

    test "returns error if Device requests ECDH384 but Owner has P-256 key (Mismatch)" do
      owner_key = %ECC{crv: :p256}

      assert {:error, :invalid_message} =
               KeyExchangeStrategy.validate("ECDH384", owner_key)
    end

    test "returns error if Device requests ECDH256 but Owner has P-384 key (Mismatch)" do
      owner_key = %ECC{crv: :p384}

      assert {:error, :invalid_message} =
               KeyExchangeStrategy.validate("ECDH256", owner_key)
    end

    test "returns error for incompatible kex algorithm / owner key type" do
      owner_key = %RSA{alg: :rs256}

      assert {:error, :invalid_message} =
               KeyExchangeStrategy.validate("ECDH256", owner_key)
    end

    test "returns error for incompatible RSA kex algorithm / owner key strength" do
      owner_key = %RSA{alg: :rs256}

      assert {:error, :invalid_message} =
               KeyExchangeStrategy.validate("DHKEXid15", owner_key)
    end

    test "returns error for unknown/unsupported device suite" do
      owner_key = %ECC{crv: :p256}

      assert {:error, :invalid_message} =
               KeyExchangeStrategy.validate("UNKNOWN_SUITE", owner_key)
    end
  end
end
