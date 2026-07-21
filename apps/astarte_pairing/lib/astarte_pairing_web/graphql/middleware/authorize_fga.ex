defmodule Astarte.PairingWeb.GraphQL.Middleware.AuthorizeFGA do
  @behaviour Absinthe.Middleware

  alias Astarte.Pairing.Config
  alias Astarte.PairingWeb.GraphQL.Auth, as: GraphQLAuth
  require Logger

  # We keep the store ID cache key as a module attribute.
  @openfga_store_id_env "ASTARTE_PAIRING_OPENFGA_STORE_ID"
  @openfga_store_id_cache_key :openfga_store_id

  def call(resolution, opts) do
    if Config.authentication_disabled?() do
      resolution
    else
      do_authorize(resolution, opts)
    end
  end

  defp do_authorize(resolution, opts) do
    context = resolution.context

    # OpenFGA arguments
    relation = Keyword.fetch!(opts, :relation)
    target_type = Keyword.fetch!(opts, :target)

    # fallback legacy arguments for when OpenFGA is not configured
    legacy_method = Keyword.get(opts, :legacy_method)
    legacy_path_fn = Keyword.get(opts, :legacy_path_fn)

    openfga_url =
      Application.get_env(:astarte_pairing, :openfga_url) ||
        System.get_env("ASTARTE_PAIRING_OPENFGA_URL") ||
        "http://localhost:8080"

    store_id = get_or_fetch_store_id(openfga_url)

    if is_nil(store_id) or store_id == "" do
      # FALLBACK LEGACY: OpenFga is not configured, fallback to legacy authorization
      legacy_path =
        if is_function(legacy_path_fn),
          do: legacy_path_fn.(resolution.arguments),
          else: Keyword.get(opts, :legacy_path)

      case GraphQLAuth.authorize_from_context(context, legacy_method, legacy_path) do
        :ok -> resolution
        {:error, msg} -> Absinthe.Resolution.put_result(resolution, {:error, msg})
      end
    else
      user = Map.get(context, :current_user)
      Logger.info("==> [OpenFGA] Current user from context: #{inspect(user)}")

      # Derive a stable user identifier from the resource loaded by Guardian.
      # Only a non-nil :id field or "sub" claim is accepted. Any other shape
      # (including a %User{id: nil}) results in nil, which will trigger the
      # {:user, _} -> Unauthorized branch below instead of sneaking past
      # authorization as a fabricated identity.
      user_id =
        case user do
          nil -> nil
          %{id: id} when not is_nil(id) -> id
          %{"sub" => sub} when not is_nil(sub) -> sub
          _ -> nil
        end

      Logger.info(
        "==> [OpenFGA] Authorizing user_id: #{inspect(user_id)} for relation: #{relation} on target_type: #{target_type}"
      )

      with {:user, uid} when not is_nil(uid) <- {:user, user_id},
           {:realm, realm_name} when not is_nil(realm_name) <-
             {:realm, Map.get(context, :realm_name)},
           :ok <-
             check_openfga(
               uid,
               relation,
               target_type,
               realm_name,
               resolution.arguments,
               store_id,
               openfga_url
             ) do
        resolution
      else
        {:user, _} ->
          Absinthe.Resolution.put_result(
            resolution,
            {:error, "Unauthorized: Missing valid user session"}
          )

        {:realm, _} ->
          Absinthe.Resolution.put_result(
            resolution,
            {:error, "Unauthorized: Missing realm context"}
          )

        {:error, :forbidden} ->
          Absinthe.Resolution.put_result(
            resolution,
            {:error, "Forbidden: OpenFGA denied access for this action"}
          )

        {:error, reason} ->
          Logger.error("OpenFGA Check failed: #{inspect(reason)}")

          Absinthe.Resolution.put_result(
            resolution,
            {:error, "Internal Server Error during authorization"}
          )
      end
    end
  end

  # Builds the OpenFGA check based on the target type (realm or device)
  defp check_openfga(user_id, relation, :realm, realm_name, _args, store_id, openfga_url) do
    call_fga_api("user:#{user_id}", relation, "realm:#{realm_name}", store_id, openfga_url)
  end

  defp check_openfga(user_id, relation, :device, _realm_name, args, store_id, openfga_url) do
    hw_id = Map.get(args, :hw_id)
    call_fga_api("user:#{user_id}", relation, "device:#{hw_id}", store_id, openfga_url)
  end

  # HTTPoison call to OpenFGA's check endpoint
  defp call_fga_api(user, relation, object, store_id, openfga_url) do
    url = "#{openfga_url}/stores/#{store_id}/check"

    body =
      Jason.encode!(%{
        "tuple_key" => %{
          "user" => user,
          "relation" => relation,
          "object" => object
        }
      })

    headers = [{"Content-Type", "application/json"}]

    Logger.info("==> [OpenFGA] OUTGOING REQUEST: POST #{url}")
    Logger.info("==> [OpenFGA] BODY: #{body}")

    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: resp_body}} ->
        Logger.info("==> [OpenFGA] SUCCESS RESPONSE: #{resp_body}")

        case Jason.decode(resp_body) do
          {:ok, %{"allowed" => true}} -> :ok
          _ -> {:error, :forbidden}
        end

      {:ok, %HTTPoison.Response{status_code: status, body: resp_body}} ->
        Logger.warning("==> [OpenFGA] NON-200 STATUS: #{status} | BODY: #{resp_body}")
        {:error, :forbidden}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("==> [OpenFGA] HTTP CONNECTION ERROR: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_or_fetch_store_id(openfga_url) do
    # First, try to see if it was provided via ENV
    env_store_id = System.get_env(@openfga_store_id_env)

    if is_nil(env_store_id) or env_store_id == "" do
      # If not in ENV, check if we have it cached in :persistent_term
      case :persistent_term.get(@openfga_store_id_cache_key, nil) do
        nil ->
          # If not cached, query OpenFGA for the first available store
          Logger.info("==> [OpenFGA] Fetching store id dynamically from #{openfga_url}/stores")

          case HTTPoison.get("#{openfga_url}/stores") do
            {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
              case Jason.decode(body) do
                {:ok, %{"stores" => [%{"id" => id} | _]}} ->
                  # Cache the ID for future requests.
                  # Note: :persistent_term is write-optimised for reads and
                  # rarely changes. To force a refresh, restart the BEAM or
                  # set ASTARTE_PAIRING_OPENFGA_STORE_ID explicitly.
                  Logger.info("==> [OpenFGA] Found and cached store id: #{id}")
                  :persistent_term.put(@openfga_store_id_cache_key, id)
                  id

                _ ->
                  Logger.warning("==> [OpenFGA] Could not find any stores")
                  nil
              end

            {:error, error} ->
              Logger.warning("==> [OpenFGA] Failed to fetch stores: #{inspect(error)}")
              nil

            _ ->
              nil
          end

        cached_id ->
          cached_id
      end
    else
      env_store_id
    end
  end
end
