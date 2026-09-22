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

defmodule Astarte.EncryptedMessages.EncryptedMessagesTest do
  use ExUnit.Case
  alias Astarte.Secrets.EncryptedMessages
  alias COSE.Keys.Symmetric
  alias COSE.Messages.Encrypt0

  describe "encrypt/2" do
    test "successfully encrypts a plaintext binary into a COSE structure using AES-256-GCM" do
      plaintext = "device_data_256"
      symmetric_key = %Symmetric{k: :crypto.strong_rand_bytes(32), alg: :aes_256_gcm}

      assert cbor_binary = EncryptedMessages.encrypt(plaintext, symmetric_key)

      assert is_binary(cbor_binary)
      assert cbor_binary != plaintext

      assert {:ok, decoded_msg} = Encrypt0.decode_cbor(cbor_binary)
      assert decoded_msg.ciphertext != nil
      assert %CBOR.Tag{tag: :bytes, value: iv} = decoded_msg.uhdr.iv
      assert is_binary(iv)
    end

    test "successfully encrypts a plaintext binary into a COSE structure using AES-128-GCM" do
      plaintext = "device_data_128"
      symmetric_key = %Symmetric{k: :crypto.strong_rand_bytes(16), alg: :aes_128_gcm}

      assert cbor_binary = EncryptedMessages.encrypt(plaintext, symmetric_key)

      assert is_binary(cbor_binary)
      assert cbor_binary != plaintext

      assert {:ok, decoded_msg} = Encrypt0.decode_cbor(cbor_binary)
      assert decoded_msg.ciphertext != nil
      assert %CBOR.Tag{tag: :bytes, value: iv} = decoded_msg.uhdr.iv
      assert is_binary(iv)
    end

    test "raises an error when session_key size is invalid" do
      plaintext = "telemetry_data_12345"
      symmetric_key = %Symmetric{k: :crypto.strong_rand_bytes(24), alg: :aes_256_gcm}

      # ExUnit asserts that this function execution crashes with an ArgumentError
      assert_raise ErlangError, fn ->
        EncryptedMessages.encrypt(plaintext, symmetric_key)
      end
    end

    test "raises an error when arguments are not binaries" do
      symmetric_key = %Symmetric{k: :crypto.strong_rand_bytes(32), alg: :aes_256_gcm}

      assert_raise ErlangError, fn ->
        EncryptedMessages.encrypt(nil, symmetric_key)
      end
    end
  end

  describe "device data encryption and decryption" do
    test "successfully encrypts and decrypts a payload using AES-256-GCM (32-byte key)" do
      plaintext = "confidential_telemetry_256"
      symmetric_key = %Symmetric{k: :crypto.strong_rand_bytes(32), alg: :aes_256_gcm}

      assert cbor_binary = EncryptedMessages.encrypt(plaintext, symmetric_key)
      assert is_binary(cbor_binary)

      assert {:ok, decrypted_plaintext} = EncryptedMessages.decrypt(cbor_binary, symmetric_key)

      assert decrypted_plaintext == plaintext
    end

    test "successfully encrypts and decrypts a payload using AES-128-GCM (16-byte key)" do
      plaintext = "confidential_telemetry_128"
      symmetric_key = %Symmetric{k: :crypto.strong_rand_bytes(16), alg: :aes_128_gcm}

      assert cbor_binary = EncryptedMessages.encrypt(plaintext, symmetric_key)
      assert is_binary(cbor_binary)

      assert {:ok, decrypted_plaintext} = EncryptedMessages.decrypt(cbor_binary, symmetric_key)

      assert decrypted_plaintext == plaintext
    end

    test "returns an error on decrypt when using a wrong session key" do
      plaintext = "secure_payload"
      symmetric_key_correct = %Symmetric{k: :crypto.strong_rand_bytes(32), alg: :aes_256_gcm}
      symmetric_key_wrong = %Symmetric{k: :crypto.strong_rand_bytes(32), alg: :aes_256_gcm}

      cbor_binary = EncryptedMessages.encrypt(plaintext, symmetric_key_correct)

      # A wrong key makes Encrypt0.decrypt return :error
      assert {:error, :decryption_failed} =
               EncryptedMessages.decrypt(cbor_binary, symmetric_key_wrong)
    end

    test "raises an error when decrypting with an invalid key size" do
      plaintext = "test_data"
      valid_key = %Symmetric{k: :crypto.strong_rand_bytes(32), alg: :aes_256_gcm}
      # 24 bytes is unsupported
      invalid_key = %Symmetric{k: :crypto.strong_rand_bytes(24), alg: :aes_256_gcm}

      cbor_binary = EncryptedMessages.encrypt(plaintext, valid_key)

      # Passing an invalid key size to the underlying Erlang crypto will raise an ErlangError
      assert_raise ErlangError, fn ->
        EncryptedMessages.decrypt(cbor_binary, invalid_key)
      end
    end

    test "returns an error when decrypt arguments are not binaries" do
      symmetric_key = %Symmetric{k: :crypto.strong_rand_bytes(32), alg: :aes_256_gcm}

      assert {:error, :decryption_failed} = EncryptedMessages.decrypt(nil, symmetric_key)
    end
  end
end
