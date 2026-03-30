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

defmodule Astarte.FDO.Core.OwnerOnboarding.SessionKeyTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.OwnerOnboarding.SessionKey
  alias COSE.Keys.ECC, as: Keys
  alias COSE.Keys.Symmetric

  describe "new/2 for ECDH suites" do
    test "ECDH256 returns random of 16 bytes and xa key exchange material" do
      key = Keys.generate(:es256)
      assert {:ok, random, xa} = SessionKey.new("ECDH256")

      assert byte_size(random) == 16
      assert is_binary(xa)
    end

    test "ECDH384 returns random of 48 bytes and xa key exchange material" do
      key = Keys.generate(:es384)
      assert {:ok, random, xa} = SessionKey.new("ECDH384")

      assert byte_size(random) == 48
      assert is_binary(xa)
    end
  end

  describe "new/2 for DHKEX suites" do
    test "DHKEXid14 returns a random and xa (mod_pow result)" do
      assert {:ok, random, xa} = SessionKey.new("DHKEXid14")

      assert byte_size(random) == 32
      assert is_binary(xa)
    end

    test "DHKEXid15 returns a random and xa (mod_pow result)" do
      assert {:ok, random, xa} = SessionKey.new("DHKEXid15")

      assert byte_size(random) == 96
      assert is_binary(xa)
    end
  end

  describe "new/2 for ASYMKEX suites" do
    test "ASYMKEX2048 returns xa equal to random (32 bytes)" do
      assert {:ok, random, xa} = SessionKey.new("ASYMKEX2048")

      assert byte_size(xa) == 32
      assert random == xa
    end

    test "ASYMKEX3072 returns xa equal to random (96 bytes)" do
      assert {:ok, random, xa} = SessionKey.new("ASYMKEX3072")

      assert byte_size(xa) == 96
      assert random == xa
    end
  end

  describe "new/2 produces different values on each call" do
    test "ECDH256 generates unique randoms" do
      key = Keys.generate(:es256)
      {:ok, random1, _xa1} = SessionKey.new("ECDH256")
      {:ok, random2, _xa2} = SessionKey.new("ECDH256")

      refute random1 == random2
    end
  end

  describe "new/2 with unknown suite" do
    test "returns {:error, :invalid_message}" do
      assert {:error, :invalid_message} = SessionKey.new("UnknownSuite")
    end
  end

  describe "compute_shared_secret/4 for ECDH suites" do
    test "ECDH256 computes a shared secret from device xb" do
      owner_key = Keys.generate(:es256)
      device_key = Keys.generate(:es256)
      {:ok, owner_random, _xa} = SessionKey.new("ECDH256")
      {:ok, _device_random, xb} = SessionKey.new("ECDH256")

      assert {:ok, shse} =
               SessionKey.compute_shared_secret("ECDH256", owner_key, owner_random, xb)

      assert is_binary(shse)
    end

    test "ECDH384 computes a shared secret from device xb" do
      owner_key = Keys.generate(:es384)
      device_key = Keys.generate(:es384)
      {:ok, owner_random, _xa} = SessionKey.new("ECDH384")
      {:ok, _device_random, xb} = SessionKey.new("ECDH384")

      assert {:ok, shse} =
               SessionKey.compute_shared_secret("ECDH384", owner_key, owner_random, xb)

      assert is_binary(shse)
    end
  end

  describe "compute_shared_secret/4 for DHKEX suites" do
    test "DHKEXid14 computes a shared secret padded to 256 bytes" do
      {:ok, owner_random, _xa} = SessionKey.new("DHKEXid14")
      {:ok, _device_random, device_xb} = SessionKey.new("DHKEXid14")

      assert {:ok, shse} =
               SessionKey.compute_shared_secret("DHKEXid14", nil, owner_random, device_xb)

      assert byte_size(shse) == 256
    end

    test "DHKEXid15 computes a shared secret padded to 384 bytes" do
      {:ok, owner_random, _xa} = SessionKey.new("DHKEXid15")
      {:ok, _device_random, device_xb} = SessionKey.new("DHKEXid15")

      assert {:ok, shse} =
               SessionKey.compute_shared_secret("DHKEXid15", nil, owner_random, device_xb)

      assert byte_size(shse) == 384
    end
  end

  describe "derive_key/4" do
    setup do
      owner_key = Keys.generate(:es256)
      device_key = Keys.generate(:es256)
      {:ok, owner_random, _} = SessionKey.new("ECDH256")
      {:ok, _, xb} = SessionKey.new("ECDH256")
      {:ok, shse256} = SessionKey.compute_shared_secret("ECDH256", owner_key, owner_random, xb)

      owner_key384 = Keys.generate(:es384)
      device_key384 = Keys.generate(:es384)
      {:ok, owner_random384, _} = SessionKey.new("ECDH384")
      {:ok, _, xb384} = SessionKey.new("ECDH384")

      {:ok, shse384} =
        SessionKey.compute_shared_secret("ECDH384", owner_key384, owner_random384, xb384)

      %{
        shse256: shse256,
        owner_random256: owner_random,
        shse384: shse384,
        owner_random384: owner_random384
      }
    end

    test "ECDH256 + :aes_128_gcm returns a 128-bit Symmetric key", %{
      shse256: shse,
      owner_random256: random
    } do
      assert {:ok, %Symmetric{alg: :aes_128_gcm, k: k}, nil, nil} =
               SessionKey.derive_key("ECDH256", :aes_128_gcm, shse, random)

      assert byte_size(k) == 16
    end

    test "ECDH256 + :aes_256_gcm returns a 256-bit Symmetric key", %{
      shse256: shse,
      owner_random256: random
    } do
      assert {:ok, %Symmetric{alg: :aes_256_gcm, k: k}, nil, nil} =
               SessionKey.derive_key("ECDH256", :aes_256_gcm, shse, random)

      assert byte_size(k) == 32
    end

    test "ECDH384 + :aes_128_gcm returns a 128-bit Symmetric key", %{
      shse384: shse,
      owner_random384: random
    } do
      assert {:ok, %Symmetric{alg: :aes_128_gcm, k: k}, nil, nil} =
               SessionKey.derive_key("ECDH384", :aes_128_gcm, shse, random)

      assert byte_size(k) == 16
    end

    test "ECDH384 + :aes_192_gcm returns a 192-bit Symmetric key", %{
      shse384: shse,
      owner_random384: random
    } do
      assert {:ok, %Symmetric{alg: :aes_192_gcm, k: k}, nil, nil} =
               SessionKey.derive_key("ECDH384", :aes_192_gcm, shse, random)

      assert byte_size(k) == 24
    end

    test "ECDH384 + :aes_256_gcm returns a 256-bit Symmetric key", %{
      shse384: shse,
      owner_random384: random
    } do
      assert {:ok, %Symmetric{alg: :aes_256_gcm, k: k}, nil, nil} =
               SessionKey.derive_key("ECDH384", :aes_256_gcm, shse, random)

      assert byte_size(k) == 32
    end
  end
end
