#
# This file is part of Astarte.
#
# Copyright 2026 Clea Srl
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

defmodule Astarte.RealmManagementWeb.GraphQL.Resolvers.InterfaceResolver do
  @moduledoc false
  alias Astarte.RealmManagement.Interfaces
  alias Astarte.RealmManagement.Interfaces.InterfacesListOptions

  def list_interfaces(_parent, args, %{context: %{realm_name: realm_name}})
      when is_binary(realm_name) do
    with {:ok, opts} <- InterfacesListOptions.from_params(args) do
      Interfaces.list_interfaces(realm_name, opts)
    end
  end

  def list_interfaces(_parent, _args, _resolution) do
    {:error, "Missing realm context"}
  end

  def get_interface(_parent, %{interface_name: name, major_version: major}, %{
        context: %{realm_name: realm_name}
      })
      when is_binary(realm_name) do
    case Interfaces.fetch_interface(realm_name, name, major) do
      {:ok, interface_map} -> {:ok, interface_map}
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def get_interface(_parent, _args, _resolution) do
    {:error, "Missing realm context"}
  end

  def get_interface_versions(_parent, %{interface_name: name}, %{
        context: %{realm_name: realm_name}
      })
      when is_binary(realm_name) do
    case Interfaces.list_interface_major_versions(realm_name, name) do
      {:ok, versions} ->
        {:ok, Enum.sort(versions, :desc)}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  def get_interface_versions(_parent, _args, _resolution) do
    {:error, "Missing realm context"}
  end

  def install_interface(_parent, args, %{context: %{realm_name: realm_name}})
      when is_binary(realm_name) do
    async = Map.get(args, :async_operation, true)

    case Interfaces.install_interface(realm_name, args.data, async: async) do
      {:ok, _interface} -> {:ok, "Interface installed successfully"}
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def install_interface(_parent, _args, _resolution) do
    {:error, "Missing realm context"}
  end

  def update_interface(
        _parent,
        %{interface_name: name, major_version: major, data: data} = args,
        %{
          context: %{realm_name: realm_name}
        }
      )
      when is_binary(realm_name) do
    async = Map.get(args, :async_operation, true)

    case Interfaces.update_interface(realm_name, name, major, data, async_operation: async) do
      :ok -> {:ok, "Interface updated successfully"}
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def update_interface(_parent, _args, _resolution) do
    {:error, "Missing realm context"}
  end

  def delete_interface_draft(_parent, %{interface_name: name, major_version: major} = args, %{
        context: %{realm_name: realm_name}
      })
      when is_binary(realm_name) do
    async = Map.get(args, :async_operation, true)

    case Interfaces.delete_interface(realm_name, name, major, async_operation: async) do
      :ok -> {:ok, "Interface draft deleted successfully"}
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def delete_interface_draft(_parent, _args, _resolution) do
    {:error, "Missing realm context"}
  end

  defp format_error(:interface_major_version_does_not_exist),
    do: "Interface major version does not exist"

  defp format_error(:interface_not_found), do: "Interface not found"
  defp format_error(:already_installed_interface), do: "Interface already installed"
  defp format_error(:interface_name_collision), do: "Interface name collision"
  defp format_error(:name_not_matching), do: "Interface name not matching"
  defp format_error(:major_version_not_matching), do: "Major version not matching"
  defp format_error(:minor_version_not_increased), do: "Minor version not increased"
  defp format_error(:invalid_update), do: "Invalid update"
  defp format_error(:downgrade_not_allowed), do: "Downgrade not allowed"
  defp format_error(:missing_endpoints), do: "Missing endpoints"
  defp format_error(:incompatible_endpoint_change), do: "Incompatible endpoint change"

  defp format_error(:cannot_delete_currently_used_interface),
    do: "Cannot delete currently used interface"

  defp format_error(:forbidden), do: "Forbidden"

  defp format_error(%Ecto.Changeset{} = changeset) do
    # Simple formatter for changeset errors
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> inspect()
  end

  defp format_error(reason), do: inspect(reason)
end
