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

defmodule Astarte.Auth.GraphQL.Middleware.AuthorizeFGA do
  @moduledoc """
  Absinthe middleware that authorizes GraphQL field resolution against
  OpenFGA, unless authentication is disabled.

  It reads the identity and the realm from the Absinthe context built by
  `Astarte.Auth.GraphQL.Plug.Context`, and checks `relation` on the object
  named by `target`:

  ```elixir
  field :list_owner_keys, :owner_keys_map do
    middleware AuthorizeFGA, relation: "fdo_read", target: :realm
    resolve &FdoResolver.list_owner_keys/3
  end
  ```

  `target` accepts:

  - `:realm` - checks against `realm:<realm from the context>`.
  - `:device` - checks against `device:<the field's `hw_id` argument>`.
  - `{type, arg}` - checks against `<type>:<the field's `arg` argument>`, for
    any other object type in the authorization model, e.g.
    `{:interface, :interface_name}`.

  Authorization fails closed: a field whose object cannot be identified (the
  context carries no realm, or the naming argument is missing) is rejected
  rather than checked against a guessed object.
  """

  @behaviour Absinthe.Middleware

  alias Astarte.Auth.OpenFGA

  require Logger

  @impl Absinthe.Middleware
  def call(resolution, opts) do
    if authentication_disabled?(resolution.context) do
      resolution
    else
      do_authorize(resolution, opts)
    end
  end

  defp do_authorize(resolution, opts) do
    context = resolution.context

    relation = Keyword.fetch!(opts, :relation)
    target = Keyword.fetch!(opts, :target)

    with {:ok, user_id} <- user_id(context),
         {:ok, realm_name} <- realm_name(context),
         {:ok, object} <- object(target, realm_name, resolution.arguments) do
      Logger.debug("Authorizing user #{inspect(user_id)} for #{relation} on #{object}")

      contextual_tuples = build_contextual_tuples(context, user_id, realm_name)

      "user:#{user_id}"
      |> OpenFGA.check(relation, object, contextual_tuples)
      |> handle_check_result(resolution)
    else
      {:error, message} -> unauthorized(resolution, message)
    end
  end

  defp build_contextual_tuples(context, user_id, realm_name) do
    # Estraiamo i ruoli dall'utente corrente nel context.
    # Assumiamo che AuthGuardian o il mapping del JWT abbiano salvato un campo :roles
    # come lista di stringhe: es. ["admin", "user"]
    Enum.map(get_roles(context), fn role ->
      %{
        user: "user:#{user_id}",
        relation: role,
        object: "realm:#{realm_name}"
      }
    end)
  end

  defp get_roles(context) do
    case Map.get(context, :current_user) do
      %{roles: roles} when is_list(roles) -> roles
      %{"roles" => roles} when is_list(roles) -> roles
      _ -> []
    end
  end

  defp handle_check_result(:ok, resolution), do: resolution

  defp handle_check_result({:error, :forbidden}, resolution),
    do: unauthorized(resolution, "Forbidden: OpenFGA denied access for this action")

  defp handle_check_result({:error, :store_not_configured}, resolution),
    do: unauthorized(resolution, "Authorization unavailable: OpenFGA store not configured")

  defp handle_check_result({:error, reason}, resolution) do
    Logger.error("OpenFGA check failed: #{inspect(reason)}")
    unauthorized(resolution, "Internal Server Error during authorization")
  end

  defp unauthorized(resolution, message),
    do: Absinthe.Resolution.put_result(resolution, {:error, message})

  # The context is built by Astarte.Auth.GraphQL.Plug.Context, which only sets
  # this once it has read the service's own configuration. A context without it
  # is one we didn't build, so enforce authorization rather than skip it.
  defp authentication_disabled?(context),
    do: Map.get(context, :authentication_disabled?, false)

  # current_user is either the user struct Guardian loaded, or the raw JWT
  # claims if it didn't. Anything else is rejected instead of guessing an
  # identity.
  defp user_id(context) do
    case Map.get(context, :current_user) do
      %{id: id} when not is_nil(id) -> {:ok, id}
      %{"sub" => sub} when not is_nil(sub) -> {:ok, sub}
      _ -> {:error, "Unauthorized: Missing valid user session"}
    end
  end

  # Every Astarte GraphQL request is realm-scoped, so a request without a realm
  # is rejected whatever its target object is.
  defp realm_name(context) do
    case Map.get(context, :realm_name) do
      nil -> {:error, "Unauthorized: Missing realm context"}
      realm_name -> {:ok, realm_name}
    end
  end

  defp object(:realm, realm_name, _arguments), do: {:ok, "realm:#{realm_name}"}

  defp object(:device, realm_name, arguments),
    do: object({:device, :hw_id}, realm_name, arguments)

  defp object({type, arg}, _realm_name, arguments) do
    case Map.get(arguments, arg) do
      nil ->
        Logger.warning("AuthorizeFGA: a #{inspect(type)}-target field was called without #{arg}")

        {:error, "Forbidden: OpenFGA denied access for this action"}

      id ->
        {:ok, "#{type}:#{id}"}
    end
  end
end
