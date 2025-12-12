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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.SessionKey do
  alias Astarte.Pairing.FDO.OwnerOnboarding.Core
  alias COSE.Keys.ECC
  alias COSE.Keys.Symmetric

  def new("ECDH256", %ECC{} = owner_key) do
    random = :crypto.strong_rand_bytes(16)
    xa = random_ecdh(owner_key, random)

    {:ok, random, xa}
  end

  def new("ECDH384", %ECC{} = key) do
    random = :crypto.strong_rand_bytes(48)
    xa = random_ecdh(key, random)
    {:ok, random, xa}
  end

  def new(_suite, _) do
    {:error, :invalid_message}
  end

  defp random_ecdh(key, random) do
    blen_r = byte_size(random)
    blen_x = byte_size(key.x)
    blen_y = byte_size(key.y)

    <<blen_x::integer-unsigned-size(16), key.x::binary, blen_y::integer-unsigned-size(16),
      key.y::binary, blen_r::integer-unsigned-size(16), random::binary>>
  end

  def compute_shared_secret(suite, %ECC{} = owner_key, owner_random, xb)
      when suite in ["ECDH256", "ECDH384"] do
    {device_random, device_public} = parse_xb_ecdh(xb)
    shse = shared_secret_ecdh(owner_key, owner_random, device_random, device_public)
    {:ok, shse}
  end

  defp parse_xb_ecdh(xb) do
    <<blen_x::integer-unsigned-size(16), rest::binary>> = xb
    <<x::binary-size(blen_x), rest::binary>> = rest
    <<blen_y::integer-unsigned-size(16), rest::binary>> = rest
    <<y::binary-size(blen_y), rest::binary>> = rest
    <<blen_r::integer-unsigned-size(16), rest::binary>> = rest
    <<device_random::binary-size(blen_r)>> = rest

    device_public = <<4, x::binary, y::binary>>

    {device_random, device_public}
  end

  defp shared_secret_ecdh(owner_key, owner_random, device_random, device_public) do
    curve =
      ECC.curve(owner_key)

    shared_secret =
      :crypto.compute_key(:ecdh, device_public, owner_key.d, curve)

    <<shared_secret::binary, device_random::binary, owner_random::binary>>
  end

  def derive_key("ECDH256", cipher_name, shared_secret, _owner_random)
      when cipher_name in [:aes_128_gcm, :aes_128_ctr, :aes_128_cbc] do
    derive_sevk(
      cipher_name,
      cipher_name,
      :hmac,
      :sha256,
      shared_secret,
      <<>>,
      128,
      256
    )
  end

  def derive_key("ECDH256", cipher_name, shared_secret, _owner_random)
      when cipher_name == :aes_256_gcm do
    derive_sevk(
      cipher_name,
      cipher_name,
      :hmac,
      :sha256,
      shared_secret,
      <<>>,
      256,
      256
    )
  end

  def derive_key("ECDH384", cipher_name, shared_secret, _owner_random)
      when cipher_name in [:aes_128_gcm, :aes_128_ctr, :aes_128_cbc] do
    derive_sevk(
      cipher_name,
      cipher_name,
      :hmac,
      :sha384,
      shared_secret,
      <<>>,
      128,
      384
    )
  end

  def derive_key("ECDH384", :aes_192_gcm, shared_secret, _owner_random) do
    derive_sevk(
      :aes_192_gcm,
      :aes_192_gcm,
      :hmac,
      :sha384,
      shared_secret,
      <<>>,
      192,
      384
    )
  end

  def derive_key("ECDH384", :aes_256_gcm, shared_secret, _owner_random) do
    derive_sevk(
      :aes_256_gcm,
      :aes_256_gcm,
      :hmac,
      :sha384,
      shared_secret,
      <<>>,
      256,
      384
    )
  end

  defp derive_sevk(
         key_type,
         cipher_aead,
         mac_type,
         mac_subtype,
         shared_secret,
         context_random,
         key_length,
         kdf_output_length
       ) do
    n = ceil(key_length / kdf_output_length)

    # The counter for each iteration, i, is a single byte
    if n > 255 do
      {:error, :too_many_iterations}
    else
      context = "AutomaticOnboardTunnel" <> context_random
      l = <<key_length::integer-big-unsigned-size(16)>>
      key_byte_length = div(key_length, 8)

      sevk =
        Core.counter_mode_kdf(mac_type, mac_subtype, n, shared_secret, context, l)
        |> binary_part(0, key_byte_length)
        |> build_key(key_type, cipher_aead)

      {:ok, sevk, nil, nil}
    end
  end

  defp build_key(binary_key, key_type, cipher_aead) do
    %Symmetric{kty: key_type, k: binary_key, alg: cipher_aead}
  end

  def to_db(nil), do: nil
  def to_db(key), do: :erlang.term_to_binary(key)
  def from_db(nil), do: nil
  def from_db(key), do: :erlang.binary_to_term(key)
end
