defmodule Astarte.Secrets do
  @moduledoc """
  Functionality to interface with OpenBao APIs.
  """
  alias Astarte.DataAccess.FDO.Queries
  alias Astarte.Secrets.Client
  alias Astarte.Secrets.Core
  alias Astarte.Secrets.Key
  alias COSE.Keys.ECC
  alias COSE.Keys.RSA
  alias HTTPoison.Response

  require Logger

  @realm_kek_key_name "realm_kek"

  @doc """
  Creates the KEK for the given realm.
  This function is idempotent when called multiple times with the same arguments.
  """
  @spec create_realm_kek(String.t(), Core.key_algorithm(), keyword()) :: term()
  def create_realm_kek(realm_name, key_type \\ :aes256, options \\ []) do
    namespace_tokens = Core.realm_kek_namespace_tokens(realm_name)
    allow_key_export_and_backup = Keyword.get(options, :allow_key_export_and_backup, false)

    with {:ok, key_type_string} <- Core.key_type_to_string(key_type),
         {:ok, namespace} <- Core.create_nested_namespace(namespace_tokens),
         :ok <- Core.mount_transit_engine(namespace),
         {:ok, response} <-
           Core.create_keypair(
             @realm_kek_key_name,
             key_type_string,
             allow_key_export_and_backup,
             namespace
           ),
         {:ok, key} <- Key.parse(@realm_kek_key_name, namespace, response) do
      {:ok, key}
    else
      result ->
        "Error creating realm kek for #{realm_name}: #{inspect(result)}"
        |> Logger.error()

        :error
    end
  end

  @doc """
  Returns the KEK for the given realm
  """
  @spec fetch_realm_kek(String.t()) :: {:ok, Key.t()} | :error
  def fetch_realm_kek(realm_name) do
    namespace = Core.realm_kek_namespace_tokens(realm_name) |> Enum.join("/")
    get_key(@realm_kek_key_name, namespace: namespace)
  end

  @spec get_key(String.t()) :: {:ok, Key.t()} | :error
  def get_key(key_name, opts \\ []) do
    namespace = Keyword.fetch!(opts, :namespace)

    with {:ok, resp} <- Core.get_key(key_name, namespace),
         {:ok, data} <- Core.parse_json_data(resp) do
      Key.parse(key_name, namespace, data)
    end
  end

  def get_key_for_guid(realm_name, user_id \\ nil, guid) do
    with {:ok, params} <- Queries.get_owner_key_params(realm_name, guid),
         {:ok, namespace} <- create_namespace(realm_name, user_id, params.algorithm) do
      get_key(params.name, namespace: namespace)
    end
  end

  @spec list_keys_names() :: {:ok, [String.t()]} | :error
  def list_keys_names(opts \\ []) do
    namespace = Keyword.fetch!(opts, :namespace)

    Core.list_keys(namespace)
  end

  def create_namespace(realm_name, user_id \\ nil, key_algorithm) do
    with {:ok, algorithm} <- Core.key_type_to_string(key_algorithm),
         namespace_tokens = Core.namespace_tokens(realm_name, user_id, algorithm),
         {:ok, namespace} <- Core.create_nested_namespace(namespace_tokens),
         :ok <- Core.mount_transit_engine(namespace) do
      {:ok, namespace}
    end
  end

  def list_namespaces do
    with {:ok, namespaces} <- Core.list_namespaces() do
      {:ok, Enum.to_list(namespaces)}
    end
  end

  @spec create_keypair(String.t(), Core.key_algorithm(), list()) ::
          {:ok, map()} | {:error, Jason.DecodeError.t()} | :error
  def create_keypair(key_name, key_type, options \\ []) do
    namespace = Keyword.fetch!(options, :namespace)
    allow_key_export_and_backup = Keyword.get(options, :allow_key_export_and_backup, false)

    with {:ok, key_type_string} <- Core.key_type_to_string(key_type) do
      Core.create_keypair(key_name, key_type_string, allow_key_export_and_backup, namespace)
    end
  end

  @spec enable_key_deletion(String.t(), list()) :: :ok | :error
  def enable_key_deletion(key_name, options \\ []) do
    req_body = %{deletion_allowed: true} |> Jason.encode!()

    headers = [{"Content-Type", "application/json"}]

    case Client.post("/transit/keys/#{key_name}/config", req_body, headers, options) do
      {:ok, %Response{status_code: 200}} ->
        :ok

      error_resp ->
        Logger.error(
          "Encountered HTTP error while enabling key deletion for key #{key_name}: #{inspect(error_resp)}"
        )

        :error
    end
  end

  @spec delete_key(String.t(), list()) :: :ok | :error
  def delete_key(key_name, options \\ []) do
    headers = []

    case Client.delete("/transit/keys/#{key_name}", headers, options) do
      {:ok, %Response{status_code: 204}} ->
        :ok

      error_resp ->
        Logger.error(
          "Encountered HTTP error while deleting key #{key_name}: #{inspect(error_resp)}"
        )

        :error
    end
  end

  @spec sign(String.t(), binary(), Core.key_algorithm(), Core.digest_type(), keyword()) ::
          {:ok, binary()} | :error
  def sign(key_name, payload, key_alg, digest_type, opts) do
    opts = Keyword.take(opts, [:namespace, :token])

    with {:ok, digest_type} <- Core.digest_type(digest_type) do
      Core.sign(key_name, payload, key_alg, digest_type, opts)
    end
  end

  @type cose_key :: %ECC{} | %RSA{}

  @spec import_key(String.t(), Core.key_algorithm(), cose_key(), list()) :: :ok | :error
  def import_key(key_name, key_type, key, opts \\ []) do
    namespace = Keyword.fetch!(opts, :namespace)
    client_opts = [namespace: namespace] ++ Keyword.take(opts, [:token])

    with {:ok, key_type_string} <- Core.key_type_to_string(key_type),
         {:ok, wrapping_key_pem} <- Core.get_wrapping_key(client_opts),
         {:ok, ciphertext} <-
           Core.prepare_import_ciphertext(Core.encode_key_to_pkcs8(key), wrapping_key_pem) do
      Core.import_key(key_name, key_type_string, ciphertext, opts)
    end
  end

  @doc """
  Generates a new Data Encryption Key (DEK) wrapped under the named transit key.
  Optional `:bits` (128 or 256, default 256).
  """
  @spec generate_dek(String.t(), String.t(), keyword()) ::
          {:ok, %{plaintext: binary(), ciphertext: String.t()}} | :error
  def generate_dek(key_name, namespace, opts \\ []) do
    Core.generate_dek(key_name, namespace, opts)
  end

  @doc """
  Unwraps a DEK ciphertext using the named transit key.
  """
  @spec unwrap_dek(String.t(), String.t(), String.t(), keyword()) :: {:ok, binary()} | :error
  def unwrap_dek(key_name, ciphertext, namespace, opts \\ []) do
    client_opts = [namespace: namespace] ++ Keyword.take(opts, [:token])
    headers = [{"Content-Type", "application/json"}]

    with {:ok, %HTTPoison.Response{status_code: 200, body: body}} <-
           Client.post(
             "/transit/decrypt/#{key_name}",
             Jason.encode!(%{ciphertext: ciphertext}),
             headers,
             client_opts
           ),
         {:ok, data} <- Core.parse_json_data(body),
         plaintext_b64 when is_binary(plaintext_b64) <- Map.get(data, "plaintext"),
         {:ok, plaintext} <- Base.decode64(plaintext_b64) do
      {:ok, plaintext}
    else
      reason ->
        Logger.error(
          "Failed to unwrap DEK with key #{key_name} in namespace #{namespace}: #{inspect(reason)}"
        )

        :error
    end
  end

  @doc """
  Encrypts `payload` using AES-256-GCM with the provided plaintext DEK.
  Returns `{:ok, blob}` where `blob` is an opaque binary containing the IV,
  authentication tag, and ciphertext. Pass the blob and DEK to `decrypt_with_dek/2`
  to recover the original payload.
  """
  @spec encrypt_with_dek(binary(), binary()) :: {:ok, binary()}
  def encrypt_with_dek(payload, dek) do
    Core.encrypt_with_dek(payload, dek)
  end

  @doc """
  Decrypts a blob produced by `encrypt_with_dek/2` using the provided plaintext DEK.
  Returns `{:ok, plaintext}` on success, or `:error` if authentication fails.
  """
  @spec decrypt_with_dek(binary(), binary()) :: {:ok, binary()} | :error
  def decrypt_with_dek(blob, dek) do
    Core.decrypt_with_dek(blob, dek)
  end

  @doc """
  Decrypts the provided ciphertext using OpenBao Transit Engine.
  Useful for ASYMKEX where the device encrypts a secret with the owner's RSA public key.
  """
  @spec decrypt(String.t(), binary(), list()) :: {:ok, binary()} | :error
  def decrypt(key_name, ciphertext, options \\ []) do
    namespace = Keyword.fetch!(options, :namespace)
    client_opts = [namespace: namespace] ++ Keyword.take(options, [:token])

    req_body =
      %{
        ciphertext: "vault:v1:" <> Base.encode64(ciphertext)
      }
      |> Jason.encode!()

    headers = [{"Content-Type", "application/json"}]

    case Client.post("/transit/decrypt/#{key_name}", req_body, headers, client_opts) do
      {:ok, %Response{status_code: 200, body: body}} ->
        with {:ok, data} <- Core.parse_json_data(body),
             plaintext_b64 when is_binary(plaintext_b64) <- Map.get(data, "plaintext"),
             {:ok, plaintext} <- Base.decode64(plaintext_b64) do
          {:ok, plaintext}
        else
          _ -> :error
        end

      error_resp ->
        Logger.error(
          "Encountered HTTP error while decrypting with key #{key_name}: #{inspect(error_resp)}"
        )

        :error
    end
  end

  @doc """
  Rotate the given key
  """
  def rotate(key_name, namespace) do
    path = "/transit/keys/#{key_name}/rotate"
    opts = [namespace: namespace]

    with {:ok, %Response{status_code: 200, body: resp}} <- Client.post(path, "", [], opts),
         {:ok, data} <- Core.parse_json_data(resp),
         {:ok, key} <- Key.parse(key_name, namespace, data) do
      {:ok, key}
    else
      error ->
        "Error while rotating key #{key_name} in namespace #{namespace}: #{inspect(error)}"
        |> Logger.error()

        :error
    end
  end

  @doc """
  Encrypts device data using AES-256-GCM with shared `session_key`.
  """
  @spec encrypt_device_data(binary(), binary(), binary()) ::
          {:ok, %{ciphertext: binary(), tag: binary(), iv: binary()}}
  def encrypt_device_data(plaintext, session_key, aad \\ <<>>)

  def encrypt_device_data(plaintext, session_key, aad)
      when is_binary(plaintext) and byte_size(session_key) == 32 and is_binary(aad) do
    try do
      iv = :crypto.strong_rand_bytes(12)

      {ciphertext, tag} =
        :crypto.crypto_one_time_aead(:aes_256_gcm, session_key, iv, plaintext, aad, true)

      {:ok, %{ciphertext: ciphertext, tag: tag, iv: iv}}
    rescue
      e ->
        require Logger
        Logger.error("Crypto module failed during AES-GCM encryption: #{inspect(e)}")
        {:error, :encryption_failed}
    end
  end

  # The provided key is not 32 bytes long
  def encrypt_device_data(plaintext, session_key, aad)
      when is_binary(plaintext) and is_binary(session_key) and is_binary(aad) do
    {:error, :invalid_key_size}
  end

  # Invalid data types (e.g., passing `nil` or a map instead of a binary)
  def encrypt_device_data(_plaintext, _session_key, _aad) do
    {:error, :invalid_arguments}
  end
end
