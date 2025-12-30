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

  # DHKEX constants as defined in RFC 3526 (for groups 14 and 15)
  @dhkex_g 2
  @dhkex_p_2048_str """
  FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD1
  29024E088A67CC74020BBEA63B139B22514A08798E3404DD
  EF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245
  E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED
  EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3D
  C2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F
  83655D23DCA3AD961C62F356208552BB9ED529077096966D
  670C354E4ABC9804F1746C08CA18217C32905E462E36CE3B
  E39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9
  DE2BCBF6955817183995497CEA956AE515D2261898FA0510
  15728E5A8AACAA68FFFFFFFFFFFFFFFF
  """
  @dhkex_p_2048 String.replace(@dhkex_p_2048_str, "\n", "") |> String.to_integer(16)
  @dhkex_p_3072_str """
  FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD1
  29024E088A67CC74020BBEA63B139B22514A08798E3404DD
  EF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245
  E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED
  EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3D
  C2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F
  83655D23DCA3AD961C62F356208552BB9ED529077096966D
  670C354E4ABC9804F1746C08CA18217C32905E462E36CE3B
  E39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9
  DE2BCBF6955817183995497CEA956AE515D2261898FA0510
  15728E5A8AAAC42DAD33170D04507A33A85521ABDF1CBA64
  ECFB850458DBEF0A8AEA71575D060C7DB3970F85A6E1E4C7
  ABF5AE8CDB0933D71E8C94E04A25619DCEE3D2261AD2EE6B
  F12FFA06D98A0864D87602733EC86A64521F2B18177B200C
  BBE117577A615D6C770988C0BAD946E208E24FA074E5AB31
  43DB5BFCE0FD108E4B82D120A93AD2CAFFFFFFFFFFFFFFFF
  """
  @dhkex_p_3072 String.replace(@dhkex_p_3072_str, "\n", "") |> String.to_integer(16)

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

  def new("DHKEXid14", _key) do
    dhkex_random = :crypto.strong_rand_bytes(32)
    # A = g^a mod p
    xa = :crypto.mod_pow(@dhkex_g, :binary.decode_unsigned(dhkex_random), @dhkex_p_2048)
    {:ok, dhkex_random, xa}
  end

  def new("DHKEXid15", _key) do
    dhkex_random = :crypto.strong_rand_bytes(96)
    # A = g^a mod p
    xa = :crypto.mod_pow(@dhkex_g, :binary.decode_unsigned(dhkex_random), @dhkex_p_3072)
    {:ok, dhkex_random, xa}
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

  def compute_shared_secret(dhkex_alg, _key, owner_random, xb)
      when dhkex_alg in ["DHKEXid14", "DHKEXid15"] do
    dhkex_p =
      case dhkex_alg do
        "DHKEXid14" ->
          @dhkex_p_2048

        "DHKEXid15" ->
          @dhkex_p_3072
      end

    # ShSe = (B^a) mod p
    shse =
      :crypto.mod_pow(
        :binary.decode_unsigned(xb),
        :binary.decode_unsigned(owner_random),
        dhkex_p
      )

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

  def derive_key(kex_alg, cipher_name, shared_secret, _owner_random)
      when kex_alg in ["ECDH256", "DHKEXid14"] and
             cipher_name in [:aes_128_gcm, :aes_128_ctr, :aes_128_cbc] do
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

  def derive_key(kex_alg, :aes_256_gcm, shared_secret, _owner_random)
      when kex_alg in ["ECDH256", "DHKEXid14"] do
    derive_sevk(
      :aes_256_gcm,
      :aes_256_gcm,
      :hmac,
      :sha256,
      shared_secret,
      <<>>,
      256,
      256
    )
  end

  def derive_key(kex_alg, cipher_name, shared_secret, _owner_random)
      when kex_alg in ["ECDH384", "DHKEXid15"] and
             cipher_name in [:aes_128_gcm, :aes_128_ctr, :aes_128_cbc] do
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

  def derive_key(kex_alg, :aes_192_gcm, shared_secret, _owner_random)
      when kex_alg in ["ECDH384", "DHKEXid15"] do
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

  def derive_key(kex_alg, :aes_256_gcm, shared_secret, _owner_random)
      when kex_alg in ["ECDH384", "DHKEXid15"] do
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

  @doc false
  @spec get_dhkex_p(integer()) :: integer() | :unsupported
  # used to retrieve p from outer modules
  def get_dhkex_p(dhkex_group) do
    case dhkex_group do
      14 ->
        @dhkex_p_2048

      15 ->
        @dhkex_p_3072

      _ ->
        raise "unsupported dhkex group #{inspect(dhkex_group)}"
    end
  end

  def to_db(nil), do: nil
  def to_db(key), do: :erlang.term_to_binary(key)
  def from_db(nil), do: nil
  def from_db(key), do: :erlang.binary_to_term(key)
end
