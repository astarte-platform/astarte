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

  It reads the user and the realm from the context built by
  `Astarte.Auth.GraphQL.Plug.Context`, and fails closed: when the check doesn't
  pass, the field gets an error instead of being resolved.

  ```elixir
  middleware AuthorizeFGA, relation: "can_read_fdo", target: :realm
  ```

  Options:

  - `:relation` - the OpenFGA relation to check.
  - `:target` - the object to check it on:
    - `:realm` - the realm from the context.
    - `:device` - the device of the realm named by the field's `hw_id` argument.
    - `{type, arg}` - the object of that type and realm named by the field's `arg` argument,
      e.g. `{:interface, :interface_name}`.

  A `sub` or an argument that can't name an OpenFGA user or object is rejected
  without calling OpenFGA. The user's `roles` count only if they are realm roles
  of the authorization model, the others are ignored.
  """

  @behaviour Absinthe.Middleware

  alias Astarte.Auth.OpenFGA
  alias Astarte.Core.Device

  require Logger

  # what OpenFGA accepts in a user or object id, and the longest user and object it takes
  @valid_id ~r/\A[^\s:#]+\z/
  @max_user_length 512
  @max_object_length 256

  @model_path :astarte_auth |> :code.priv_dir() |> Path.join("authorization_model.json")
  @external_resource @model_path

  @realm_relations @model_path
                   |> File.read!()
                   |> Jason.decode!()
                   |> Map.fetch!("type_definitions")
                   |> Enum.find(&(&1["type"] == "realm"))
                   |> get_in(["metadata", "relations"])

  # the realm relations a user can be assigned directly
  @realm_roles for {relation, %{"directly_related_user_types" => types}} <- @realm_relations,
                   %{"type" => "user"} <- types,
                   into: MapSet.new(),
                   do: relation

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
         {:ok, user} <- user(realm_name, user_id),
         {:ok, object} <- object(target, realm_name, resolution.arguments) do
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
      %{roles: roles} when is_list(roles) -> realm_roles(roles)
      _ -> []
    end
  end

  defp realm_roles(roles) do
    roles = MapSet.new(roles)
    ignored = MapSet.difference(roles, @realm_roles)

    if MapSet.size(ignored) > 0 do
      Logger.debug("AuthorizeFGA: ignoring roles the model doesn't define",
        ignored_roles: inspect(MapSet.to_list(ignored))
      )
    end

    roles |> MapSet.intersection(@realm_roles) |> MapSet.to_list()
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

  defp user(realm_name, user_id) do
    with :error <- qualified_name(:user, realm_name, user_id, @max_user_length) do
      Logger.warning(
        "AuthorizeFGA: a token of realm #{realm_name} has an invalid sub: #{inspect(user_id)}"
      )

      {:error, "Unauthorized: invalid user identity"}
    end
  end

  defp object(:realm, realm_name, _arguments), do: {:ok, "realm:#{realm_name}"}

  defp object(:device, realm_name, arguments),
    do: object({:device, :hw_id}, realm_name, arguments)

  defp object({type, arg}, realm_name, arguments) do
    case Map.fetch(arguments, arg) do
      {:ok, id} when not is_nil(id) ->
        named_object(type, arg, id, realm_name)

      _ ->
        Logger.warning("AuthorizeFGA: a #{inspect(type)}-target field was called without #{arg}")

        {:error, "Forbidden: OpenFGA denied access for this action"}
    end
  end

  defp named_object(type, arg, id, realm_name) do
    with :error <- qualified_object(type, realm_name, id) do
      Logger.debug("AuthorizeFGA: invalid #{arg}: #{inspect(id)}")

      {:error, "Invalid argument: #{arg}"}
    end
  end

  # equivalent encodings of a device id must name the same object
  defp qualified_object(:device, realm_name, hw_id) when is_binary(hw_id) do
    case Device.decode_device_id(hw_id) do
      {:ok, device_id} ->
        encoded_id = Device.encode_device_id(device_id)
        qualified_name(:device, realm_name, encoded_id, @max_object_length)

      {:error, _reason} ->
        :error
    end
  end

  defp qualified_object(type, realm_name, id),
    do: qualified_name(type, realm_name, id, @max_object_length)

  defp qualified_name(type, realm_name, id, max_length) when is_binary(id) do
    name = "#{type}:#{realm_name}/#{id}"

    if Regex.match?(@valid_id, id) and String.length(name) <= max_length,
      do: {:ok, name},
      else: :error
  end

  defp qualified_name(_type, _realm_name, _id, _max_length), do: :error
end
