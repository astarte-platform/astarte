defmodule Astarte.Secrets do
  @moduledoc """
  Functionality to interface with OpenBao APIs.
  """
  alias Astarte.Secrets.Client
  alias Astarte.Secrets.Core
  alias Astarte.Secrets.Key
  alias COSE.Keys.ECC
  alias COSE.Keys.RSA
  alias Astarte.DataAccess.FDO.Queries

  require Logger

  @spec get_key(String.t()) :: {:ok, map()} | :error
  def get_key(key_name, opts \\ []) do
    namespace = Keyword.fetch!(opts, :namespace)

    with {:ok, resp} <- Core.get_key(key_name, namespace) do
      Key.parse(key_name, namespace, resp)
    end
  end

  def get_key_for_guid(realm_name, user_id \\ nil, guid) do
    with {:ok, params} <- Queries.get_owner_key_params(realm_name, guid),
         {:ok, namespace} <- create_namespace(realm_name, user_id, params.key_algorithm) do
      get_key(params.key_name, namespace: namespace)
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
      {:ok, %HTTPoison.Response{status_code: 200}} ->
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
      {:ok, %HTTPoison.Response{status_code: 204}} ->
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
end
