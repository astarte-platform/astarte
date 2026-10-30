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
  OpenFGA.

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
  - `:device` - checks against `device:<realm>/<the field's `hw_id` argument>`.
  - `{type, arg}` - checks against `<type>:<realm>/<the field's `arg` argument>`,
    for any other object type in the authorization model, e.g.
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
    relation = Keyword.fetch!(opts, :relation)
    target = Keyword.fetch!(opts, :target)

    case authorize(resolution, relation, target) do
      :ok -> resolution
      {:error, message} -> Absinthe.Resolution.put_result(resolution, {:error, message})
    end
  end

  defp authorize(resolution, relation, target) do
    context = resolution.context

    with {:ok, user_id} <- user_id(context),
         {:ok, realm_name} <- realm_name(context),
         {:ok, object} <- object(target, realm_name, resolution.arguments) do
      user = "user:#{realm_name}/#{user_id}"
      Logger.debug("Authorizing #{user} for #{relation} on #{object}")

      user
      |> OpenFGA.check(relation, object, contextual_tuples(context, user, realm_name, object))
      |> check_result()
    end
  end

  defp contextual_tuples(context, user, realm_name, object) do
    realm = "realm:#{realm_name}"
    role_tuple = %{user: user, object: realm}

    role_tuples =
      context
      |> get_roles()
      |> Enum.map(&Map.put(role_tuple, :relation, &1))

    if object == realm,
      do: role_tuples,
      else: role_tuples ++ [%{user: realm, relation: "realm", object: object}]
  end

  defp get_roles(context) do
    case Map.get(context, :current_user) do
      %{roles: roles} when is_list(roles) -> roles
      _ -> []
    end
  end

  defp check_result(:ok), do: :ok

  defp check_result({:error, :forbidden}),
    do: {:error, "Forbidden: OpenFGA denied access for this action"}

  defp check_result({:error, reason}) do
    Logger.error("OpenFGA check failed: #{inspect(reason)}")
    {:error, "Internal Server Error during authorization"}
  end

  # current_user is nil when there was no valid token
  defp user_id(context) do
    case Map.get(context, :current_user) do
      %{id: id} when not is_nil(id) -> {:ok, id}
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

  defp object({type, arg}, realm_name, arguments) do
    case Map.fetch(arguments, arg) do
      {:ok, id} when not is_nil(id) ->
        {:ok, "#{type}:#{realm_name}/#{id}"}

      _ ->
        Logger.warning("AuthorizeFGA: a #{inspect(type)}-target field was called without #{arg}")

        {:error, "Forbidden: OpenFGA denied access for this action"}
    end
  end
end
