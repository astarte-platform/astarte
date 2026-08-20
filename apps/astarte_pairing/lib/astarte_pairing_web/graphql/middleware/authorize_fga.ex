defmodule Astarte.PairingWeb.GraphQL.Middleware.AuthorizeFGA do
  @moduledoc """
  Absinthe middleware that authorizes GraphQL field resolution against
  OpenFGA, unless authentication is disabled.
  """

  @behaviour Absinthe.Middleware

  alias Astarte.Pairing.Config
  alias Astarte.Pairing.OpenFGA
  require Logger

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

    user_id = user_id(context)
    realm_name = Map.get(context, :realm_name)

    cond do
      is_nil(user_id) ->
        unauthorized(resolution, "Unauthorized: Missing valid user session")

      is_nil(realm_name) ->
        unauthorized(resolution, "Unauthorized: Missing realm context")

      true ->
        Logger.debug(
          "Authorizing user_id: #{inspect(user_id)} for relation: #{relation} on target_type: #{target_type}"
        )

        case check(user_id, relation, target_type, realm_name, resolution.arguments) do
          :ok ->
            resolution

          {:error, :forbidden} ->
            unauthorized(resolution, "Forbidden: OpenFGA denied access for this action")

          {:error, reason} ->
            Logger.error("OpenFGA check failed: #{inspect(reason)}")
            unauthorized(resolution, "Internal Server Error during authorization")
        end
    end
  end

  defp unauthorized(resolution, message),
    do: Absinthe.Resolution.put_result(resolution, {:error, message})

  # current_user is either the %User{} Guardian loaded, or the raw JWT
  # claims if it didn't. Anything else returns nil, so the request gets
  # rejected instead of guessing an identity.
  defp user_id(context) do
    case Map.get(context, :current_user) do
      %{id: id} when not is_nil(id) -> id
      %{"sub" => sub} when not is_nil(sub) -> sub
      _ -> nil
    end
  end

  # Builds the OpenFGA check based on the target type (realm or device)
  defp check(user_id, relation, :realm, realm_name, _args) do
    OpenFGA.check("user:#{user_id}", relation, "realm:#{realm_name}")
  end

  defp check(user_id, relation, :device, _realm_name, args) do
    hw_id = Map.get(args, :hw_id)
    OpenFGA.check("user:#{user_id}", relation, "device:#{hw_id}")
  end
end
