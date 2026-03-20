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

defmodule Astarte.Pairing.FDO.OpenBao.Core do
  @moduledoc """
  Implementation of function to interface with OpenBao.
  """

  alias Astarte.DataAccess.Config, as: DataAccessConfig
  alias Astarte.Pairing.FDO.OpenBao.Client
  alias COSE.Keys.ECC
  alias COSE.Keys.RSA
  alias HTTPoison.Response

  require Logger

  @type key_algorithm() :: :es256 | :es384 | :rs256 | :rs384
  @type digest_type() :: :crypto.sha1() | :crypto.sha2()

  # RFC 5649 AES Key Wrap with Padding magic constant
  @aes_kwp_magic <<0xA6, 0x59, 0x59, 0xA6>>

  @spec key_type_to_string(key_algorithm()) :: {:ok, String.t()} | :error
  def key_type_to_string(key_type) do
    case key_type do
      :es256 -> {:ok, "ecdsa-p256"}
      :es384 -> {:ok, "ecdsa-p384"}
      :rs256 -> {:ok, "rsa-2048"}
      :rs384 -> {:ok, "rsa-3072"}
      _ -> :error
    end
  end

  @spec digest_type(digest_type) :: {:ok, String.t()} | :error
  def digest_type(:sha), do: {:ok, "sha1"}
  def digest_type(:sha224), do: {:ok, "sha2-224"}
  def digest_type(:sha256), do: {:ok, "sha2-256"}
  def digest_type(:sha384), do: {:ok, "sha2-384"}
  def digest_type(:sha512), do: {:ok, "sha2-512"}
  def digest_type(:sha3_224), do: {:ok, "sha3-224"}
  def digest_type(:sha3_256), do: {:ok, "sha3-256"}
  def digest_type(:sha3_384), do: {:ok, "sha3-384"}
  def digest_type(:sha3_512), do: {:ok, "sha3-512"}

  def digest_type(digest_type) do
    Logger.warning("Invalid digest type: #{inspect(digest_type)}")
    :error
  end

  @spec create_keypair(String.t(), String.t(), boolean(), String.t()) ::
          :error | {:error, Jason.DecodeError.t()} | {:ok, any()}
  def create_keypair(key_name, key_type, allow_key_export_and_backup, namespace) do
    req_body =
      %{
        type: key_type,
        exportable: allow_key_export_and_backup,
        allow_plaintext_backup: allow_key_export_and_backup
      }
      |> Jason.encode!()

    headers = [{"Content-Type", "application/json"}]

    options = [{:namespace, namespace}]

    case Client.post("/transit/keys/#{key_name}", req_body, headers, options) do
      {:ok, %HTTPoison.Response{status_code: 200, body: resp_body}} ->
        parse_json_data(resp_body)

      error_resp ->
        Logger.error(
          "Encountered HTTP error while creating key #{key_name}: #{inspect(error_resp)}"
        )

        :error
    end
  end

  def get_wrapping_key(opts) do
    case Client.get("/transit/wrapping_key", [], opts) do
      {:ok, %HTTPoison.Response{status_code: 200, body: resp_body}} ->
        with {:error, reason} <- parse_data_key(resp_body, "public_key") do
          Logger.error("Failed to get wrapping key: #{inspect(reason)}")
          {:error, :wrapping_key_parse_failed}
        end

      error_resp ->
        Logger.error("Encountered HTTP error while fetching wrapping key: #{inspect(error_resp)}")
        :error
    end
  end

  # Prepares the BYOK ciphertext for importing key material into OpenBao.
  def prepare_import_ciphertext(key_material, wrapping_key_pem) do
    with {:ok, rsa_public_key} <- decode_pem_public_key(wrapping_key_pem) do
      # Generate a random 256-bit AES ephemeral key
      aes_key = :crypto.strong_rand_bytes(32)

      # Wrap the key material with AES-256-KWP (RFC 5649)
      wrapped_key_material = aes_key_wrap_with_padding(aes_key, key_material)

      # Wrap the AES key with the RSA wrapping key using RSA-OAEP + SHA-256
      wrapped_aes_key =
        :public_key.encrypt_public(aes_key, rsa_public_key,
          rsa_padding: :rsa_pkcs1_oaep_padding,
          rsa_oaep_md: :sha256
        )

      # OpenBao expects: RSA-OAEP(aes_key) [512 bytes] || AES-KWP(key_material)
      {:ok, Base.encode64(wrapped_aes_key <> wrapped_key_material)}
    end
  end

  @doc """
  Posts pre-built BYOK `ciphertext` to the OpenBao transit import endpoint.

  `opts` can include:
    - `:allow_rotation`         - allow key rotation inside OpenBao; defaults to false
    - `:exportable`             - allow key export; irreversible; defaults to false
    - `:allow_plaintext_backup` - allow plaintext backups; irreversible; defaults to false
    - `:auto_rotate_period`     - auto-rotation period, e.g. "1h"; "0" disables; defaults to "0"
    - `:namespace`              - OpenBao namespace to target
    - `:token`                  - override the configured auth token
  """
  @spec import_key(String.t(), String.t(), String.t(), keyword()) :: :ok | :error
  def import_key(key_name, key_type_string, ciphertext, opts \\ []) do
    client_opts = Keyword.take(opts, [:namespace, :token])

    req_body =
      %{
        type: key_type_string,
        ciphertext: ciphertext,
        # must match the rsa_oaep_md used in prepare_import_ciphertext
        hash_function: "SHA256",
        allow_rotation: Keyword.get(opts, :allow_rotation, false),
        exportable: Keyword.get(opts, :exportable, false),
        allow_plaintext_backup: Keyword.get(opts, :allow_plaintext_backup, false),
        auto_rotate_period: Keyword.get(opts, :auto_rotate_period, "0")
      }
      |> Jason.encode!()

    headers = [{"Content-Type", "application/json"}]

    case Client.post("/transit/keys/#{key_name}/import", req_body, headers, client_opts) do
      {:ok, %HTTPoison.Response{status_code: 204}} ->
        :ok

      error_resp ->
        Logger.error(
          "Encountered HTTP error while importing key #{key_name}: #{inspect(error_resp)}"
        )

        :error
    end
  end

  # Encodes a COSE key (ECC or RSA) into PKCS#8 DER format,
  # which is what OpenBao expects as key_material for key import.
  def encode_key_to_pkcs8(%ECC{} = key),
    do: key |> ECC.to_record() |> X509.PrivateKey.to_der(wrap: true)

  def encode_key_to_pkcs8(%RSA{} = key),
    do: key |> RSA.to_record() |> X509.PrivateKey.to_der(wrap: true)

  # RFC 5649 AES Key Wrap with Padding (AES-KWP)
  # Used by OpenBao for BYOK import (replaces plain RFC 3394 AES-KW).
  defp aes_key_wrap_with_padding(aes_key, plaintext) do
    mlen = byte_size(plaintext)
    aiv = @aes_kwp_magic <> <<mlen::unsigned-big-integer-size(32)>>

    # pad to multiple of 8 bytes
    pad_len = rem(8 - rem(mlen, 8), 8)
    padded = plaintext <> :binary.copy(<<0>>, pad_len)

    n = div(byte_size(padded), 8)

    if n == 1 do
      # single 8-byte block: one AES-ECB encryption of AIV || padded
      :crypto.crypto_one_time(:aes_256_ecb, aes_key, <<>>, aiv <> padded, true)
    else
      # RFC 3394 W algorithm with KWP AIV
      r = for i <- 0..(n - 1), do: binary_part(padded, i * 8, 8)

      {a, r} =
        Enum.reduce(0..5, {aiv, r}, fn j, {a, r} ->
          Enum.reduce(0..(n - 1), {a, r}, &aes_kwp_step(aes_key, n, j, &1, &2))
        end)

      Enum.reduce(r, a, fn ri, acc -> acc <> ri end)
    end
  end

  defp aes_kwp_step(aes_key, n, j, i, {a, r}) do
    ri = Enum.at(r, i)
    b = :crypto.crypto_one_time(:aes_256_ecb, aes_key, <<>>, a <> ri, true)
    msb = binary_part(b, 0, 8)
    lsb = binary_part(b, 8, 8)
    t = j * n + (i + 1)
    a_new = :crypto.exor(msb, <<t::unsigned-big-integer-size(64)>>)
    {a_new, List.replace_at(r, i, lsb)}
  end

  defp decode_pem_public_key(pem_string) do
    case :public_key.pem_decode(pem_string) do
      [entry | _] ->
        {:ok, :public_key.pem_entry_decode(entry)}

      [] ->
        Logger.error("PEM decode returned no entries")
        {:error, :pem_decode_failed}
    end
  end

  @spec get_key(String.t(), String.t()) ::
          :error | {:error, Jason.DecodeError.t()} | {:ok, any()}
  def get_key(key_name, namespace) do
    headers = [{"Content-Type", "application/json"}]

    options = [{:namespace, namespace}]

    case Client.get("/transit/keys/#{key_name}", headers, options) do
      {:ok, %HTTPoison.Response{status_code: 200, body: resp_body}} ->
        parse_json_data(resp_body)

      error_resp ->
        Logger.error(
          "Encountered HTTP error while getting key #{key_name}: #{inspect(error_resp)}"
        )

        :error
    end
  end

  @spec list_keys(String.t()) :: {:ok, [String.t()]} | :error
  def list_keys(namespace) do
    headers = [{"Content-Type", "application/json"}]

    options = [{:namespace, namespace}]

    case Client.list("/transit/keys", headers, options) do
      {:ok, %HTTPoison.Response{status_code: 200, body: resp_body}} ->
        case parse_data_key(resp_body, "keys") do
          {:ok, keys} ->
            {:ok, keys}

          {:error, reason} ->
            Logger.error("Encountered HTTP error while getting keys list: #{inspect(reason)}")
            :error
        end

      {:ok, %HTTPoison.Response{status_code: 404}} ->
        {:ok, []}

      error_resp ->
        Logger.error("Encountered HTTP error while getting keys list: #{inspect(error_resp)}")

        :error
    end
  end

  @doc """
  Returns the namespace name for the given params, represented as a list of tokens
  """
  def namespace_tokens(realm_name, user_id, key_algorithm) do
    ["fdo_owner_keys", instance_tokens(), realm_name, user_tokens(user_id), key_algorithm]
    |> List.flatten()
  end

  defp instance_tokens do
    case DataAccessConfig.astarte_instance_id!() do
      "" ->
        "default_instance"

      instance_id ->
        ["instance", instance_id]
    end
  end

  defp user_tokens(nil), do: "default_user"
  defp user_tokens(user_id), do: ["user_id", user_id]

  def create_nested_namespace(namespace_tokens) do
    Enum.reduce_while(namespace_tokens, {:ok, ""}, fn new_namespace, {:ok, base_namespace} ->
      headers = []
      options = [namespace: base_namespace]

      case Client.post("/sys/namespaces/#{new_namespace}", "", headers, options) do
        {:ok, %HTTPoison.Response{status_code: 200}} ->
          new_base_namespace = Path.join(base_namespace, new_namespace)
          {:cont, {:ok, new_base_namespace}}

        error ->
          "Error creating new namespace #{new_namespace} on #{base_namespace}: #{inspect(error)}"
          |> Logger.error()

          {:halt, {:error, :namespace_creation_error}}
      end
    end)
  end

  def mount_transit_engine(namespace) do
    req_body = %{type: "transit"} |> Jason.encode!()
    headers = [{"Content-Type", "application/json"}]
    options = [{:namespace, namespace}]

    case Client.post("/sys/mounts/transit", req_body, headers, options) do
      {:ok, %Response{status_code: 204}} ->
        :ok

      {:ok, %Response{status_code: 400, body: body}} = resp ->
        if "already in use at transit" =~ body do
          :ok
        else
          "Encountered HTTP error while mounting transit engine in namespace #{namespace}: #{inspect(resp)}"
          |> Logger.error()
        end

      error_resp ->
        Logger.error(
          "Encountered HTTP error while mounting transit engine in namespace #{namespace}: #{inspect(error_resp)}"
        )

        :error
    end
  end

  defp parse_data_key(json_str, key) do
    with {:ok, data} <- parse_json_data(json_str) do
      fetch_data_key(data, key)
    end
  end

  defp parse_json_data(json_str) do
    with {:ok, map} when is_map(map) <- Jason.decode(json_str),
         {:ok, data} <- Map.fetch(map, "data") do
      {:ok, data}
    else
      _ -> {:error, {:invalid_response_body, json_str}}
    end
  end

  defp fetch_data_key(data, key) do
    with :error <- Map.fetch(data, key) do
      {:error, {:unexpected_body_format, data}}
    end
  end

  def list_namespaces(base_namespace \\ "", acc \\ MapSet.new()) do
    with {:ok, children} <- list_relative_namespaces(base_namespace) do
      child_namespaces = children |> Enum.map(&(base_namespace <> &1))
      acc = child_namespaces |> MapSet.new() |> MapSet.union(acc)

      Enum.reduce_while(children, {:ok, acc}, &do_list_namespaces(base_namespace, &1, &2))
    end
  end

  defp list_relative_namespaces(base_namespace) do
    headers = [{"X-Vault-Namespace", base_namespace}]

    case Client.list("/sys/namespaces", headers) do
      {:ok, %Response{status_code: 200, body: body}} ->
        case parse_data_key(body, "keys") do
          {:ok, _keys} = ok ->
            ok

          error ->
            Logger.warning("Error while listing namespaces: #{inspect(error)}")
            error
        end

      {:ok, %Response{status_code: 404}} ->
        # Responds with 404 when there is no relative namespace
        {:ok, []}

      error ->
        Logger.warning("Error while listing namespaces: #{inspect(error)}")
        error
    end
  end

  defp do_list_namespaces(base_namespace, child, {:ok, acc}) do
    child_namespace = base_namespace <> child

    case list_namespaces(child_namespace, acc) do
      {:ok, child_branch} ->
        acc = child_branch |> MapSet.new() |> MapSet.union(acc)
        {:cont, {:ok, acc}}

      error ->
        {:halt, error}
    end
  end

  @doc """
  Signs data using a key stored in OpenBao's transit engine.
  Translates FDO/COSE algorithms to the specific OpenBao parameters.
  """
  @spec sign(String.t(), binary(), key_algorithm(), String.t(), keyword()) ::
          {:ok, binary()} | :error
  def sign(key_name, payload, key_alg, digest_type, opts) do
    vault_opts = map_cose_alg_to_vault_opts(key_alg)
    url_path = "/transit/sign/#{key_name}/#{digest_type}"

    req_body = build_sign_payload(payload, vault_opts)
    headers = [{"Content-Type", "application/json"}]
    marshaling = Keyword.get(vault_opts, :marshaling_algorithm)

    with {:ok, %HTTPoison.Response{status_code: 200, body: resp_body}} <-
           Client.post(url_path, req_body, headers, opts),
         {:ok, raw_sig} <- extract_and_decode_signature(resp_body, marshaling) do
      {:ok, raw_sig}
    else
      error ->
        Logger.error("Failed to sign payload or decode Vault response: #{inspect(error)}")
        :error
    end
  end

  # Builds the JSON payload to send to Vault based on the algorithm options
  defp build_sign_payload(payload, vault_opts) do
    vault_opts
    |> Keyword.take([:signature_algorithm, :marshaling_algorithm])
    |> Map.new()
    |> Map.put(:input, Base.encode64(payload))
    |> Jason.encode!()
  end

  # Parses the JSON response, extracts the signature string, and decodes it into a binary
  defp extract_and_decode_signature(resp_body, marshaling) do
    with {:ok, vault_sig} <- parse_data_key(resp_body, "signature"),
         true <- is_binary(vault_sig),
         [_, _, b64_sig] <- String.split(vault_sig, ":", parts: 3) do
      # decode_vault_sig returns {:ok, raw_sig} or :error
      decode_vault_sig(b64_sig, marshaling)
    else
      {:error, _reason} = error ->
        error

      _ ->
        :error
    end
  end

  # Decodes the Base64 signature returned by OpenBao.
  # When using the "jws" marshaling algorithm, OpenBao returns a
  # URL-safe Base64 string without padding.
  defp decode_vault_sig(b64_sig, "jws") do
    Base.url_decode64(b64_sig, padding: false)
  end

  # For "asn1" or default marshaling, OpenBao uses standard Base64 encoding.
  defp decode_vault_sig(b64_sig, _other) do
    Base.decode64(b64_sig)
  end

  # Translates Astarte/COSE supported algorithms into OpenBao Transit engine parameters.
  defp map_cose_alg_to_vault_opts(:es256) do
    [marshaling_algorithm: "jws"]
  end

  defp map_cose_alg_to_vault_opts(:es384) do
    [marshaling_algorithm: "jws"]
  end

  defp map_cose_alg_to_vault_opts(:rs256) do
    [signature_algorithm: "pkcs1v15"]
  end

  defp map_cose_alg_to_vault_opts(:rs384) do
    [signature_algorithm: "pkcs1v15"]
  end
end
