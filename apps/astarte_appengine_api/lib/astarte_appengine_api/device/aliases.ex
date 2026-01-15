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

defmodule Astarte.AppEngine.API.Device.Aliases do
  alias Astarte.DataAccess.Devices.Device
  alias Ecto.Changeset

  alias Astarte.AppEngine.API.Device.Queries

  require Logger

  defstruct to_update: [], to_delete: []

  @type input :: %{alias_tag => alias_value} | [alias]
  @type alias_tag :: String.t()
  @type alias_value :: String.t()
  @type alias :: {alias_tag, alias_value}
  @type t :: %__MODULE__{
          to_update: [alias],
          to_delete: [alias_tag]
        }

  @spec validate(input() | nil, String.t(), Device.t()) :: {:ok, t()} | term()
  def validate(nil, _, _), do: {:ok, %__MODULE__{to_delete: [], to_update: []}}

  def validate(aliases, realm_name, device) do
    with :ok <- validate_format(aliases) do
      {to_delete, to_update} = aliases |> Enum.split_with(fn {_key, value} -> is_nil(value) end)
      to_delete = to_delete |> Enum.map(fn {tag, nil} -> tag end)
      state = %__MODULE__{to_delete: to_delete, to_update: to_update}

      with :ok <- validate_device_ownership(state, realm_name, device) do
        {:ok, state}
      end
    end
  end

  @spec apply(Changeset.t(), t()) :: Changeset.t()
  def apply(changeset, aliases) do
    %__MODULE__{to_delete: to_delete, to_update: to_update} = aliases

    changeset
    |> apply_delete(to_delete)
    |> apply_update(to_update)
  end

  @spec validate_format(input()) :: :ok | {:error, :invalid_alias}
  defp validate_format(aliases) do
    Enum.find_value(aliases, :ok, fn
      {_tag, ""} ->
        :invalid_value

      {"", _value} ->
        :invalid_tag

      _valid_format_tag ->
        false
    end)
    |> case do
      :ok ->
        :ok

      :invalid_tag ->
        Logger.warning("Alias key cannot be an empty string.", tag: :invalid_alias_empty_key)
        {:error, :invalid_alias}

      :invalid_value ->
        Logger.warning("Alias value cannot be an empty string.", tag: :invalid_alias_empty_value)
        {:error, :invalid_alias}
    end
  end

  @spec validate_device_ownership(t(), String.t(), Device.t()) :: :ok
  defp validate_device_ownership(aliases, realm_name, device) do
    %__MODULE__{to_delete: to_delete, to_update: to_update} = aliases

    to_delete = device.aliases |> Map.take(to_delete) |> Enum.map(fn {_tag, value} -> value end)
    to_update = to_update |> Enum.map(fn {_tag, value} -> value end)

    all_aliases = to_delete ++ to_update

    invalid_name =
      Queries.find_all_aliases(realm_name, all_aliases)
      |> Enum.find(fn name -> name.object_uuid != device.device_id end)

    if is_nil(invalid_name) do
      :ok
    else
      existing_aliases =
        Enum.find(device.aliases, fn {_tag, value} -> value == invalid_name.object_name end)

      inconsistent? = !is_nil(existing_aliases)

      if inconsistent? do
        {invalid_tag, _value} = existing_aliases

        Logger.error("Inconsistent alias for #{invalid_tag}.",
          device_id: device.device_id,
          tag: "inconsistent_alias"
        )

        {:error, :database_error}
      else
        {:error, :alias_already_in_use}
      end
    end
  end

  @spec apply_delete(Changeset.t(), [alias]) :: Changeset.t()
  defp apply_delete(%Changeset{valid?: false} = changeset, _delete_aliases),
    do: changeset

  defp apply_delete(changeset, [] = _delete_aliases),
    do: changeset

  defp apply_delete(changeset, delete_aliases) do
    aliases = changeset |> Changeset.fetch_field!(:aliases)

    delete_tags = delete_aliases |> MapSet.new()

    device_aliases = aliases |> Map.keys() |> MapSet.new()

    if MapSet.subset?(delete_tags, device_aliases) do
      aliases = aliases |> Map.drop(delete_aliases)

      changeset
      |> Changeset.put_change(:aliases, aliases)
    else
      Changeset.add_error(changeset, :aliases, "", reason: :alias_tag_not_found)
    end
  end

  @spec apply_update(Changeset.t(), [alias]) :: Changeset.t()
  defp apply_update(%Changeset{valid?: false} = changeset, _update_aliases),
    do: changeset

  defp apply_update(changeset, update_aliases) when update_aliases == [],
    do: changeset

  defp apply_update(changeset, update_aliases) do
    aliases =
      changeset |> Changeset.fetch_field!(:aliases)

    aliases = Map.merge(aliases, Map.new(update_aliases))

    Changeset.put_change(changeset, :aliases, aliases)
  end
end
