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

defmodule Astarte.AppEngine.API.Device.Attributes do
  @moduledoc """
  Handles validation and application of Device Attributes.

  This module manage the update and deletion of Device Attributes (Stored as 
  key-Value pairs) in an Ecto Changeset while ensuring data integrity through validation.
  """
  alias Ecto.Changeset

  require Logger

  defstruct to_update: [], to_delete: []

  @type input :: %{attribute_tag => attribute_value} | [attribute]
  @type attribute_tag :: String.t()
  @type attribute_value :: String.t()
  @type attribute :: {attribute_tag, attribute_value}
  @type t ::
          %__MODULE__{
            to_update: [attribute],
            to_delete: [attribute_tag]
          }

  @spec validate(input() | nil) :: {:ok, t()} | term()
  def validate(attributes) do
    attributes =
      case attributes do
        nil -> []
        attributes -> attributes
      end

    with :ok <- validate_format(attributes) do
      {to_delete, to_update} =
        attributes
        |> Enum.split_with(fn {_key, value} -> is_nil(value) end)

      to_delete = to_delete |> Enum.map(fn {key, nil} -> key end)

      {:ok, %__MODULE__{to_delete: to_delete, to_update: to_update}}
    end
  end

  @spec apply(Changeset.t(), t()) :: Changeset.t()
  def apply(changeset, attributes) do
    %__MODULE__{to_delete: to_delete, to_update: to_update} = attributes

    changeset
    |> apply_delete(to_delete)
    |> apply_update(to_update)
  end

  @spec validate_format(input()) :: :ok | {:error, :invalid_attributes}
  defp validate_format(attributes) do
    invalid_attribute? =
      Enum.any?(attributes, fn {attribute_key, _value} -> attribute_key == "" end)

    if invalid_attribute? do
      Logger.warning("Attribute key cannot be an empty string.",
        tag: :invalid_attribute_empty_key
      )

      {:error, :invalid_attributes}
    else
      :ok
    end
  end

  @spec apply_delete(Changeset.t(), [attribute_tag]) :: Changeset.t()
  defp apply_delete(%Changeset{valid?: false} = changeset, _delete_attributes), do: changeset

  defp apply_delete(changeset, delete_attributes) when delete_attributes == [],
    do: changeset

  defp apply_delete(changeset, delete_attributes) do
    attributes = changeset |> Changeset.fetch_field!(:attributes)

    attributes_to_delete = delete_attributes |> MapSet.new()

    device_attributes = attributes |> Map.keys() |> MapSet.new()

    if MapSet.subset?(attributes_to_delete, device_attributes) do
      attributes = attributes |> Map.drop(delete_attributes)

      changeset
      |> Changeset.put_change(:attributes, attributes)
    else
      Changeset.add_error(changeset, :attributes, "", reason: :attribute_key_not_found)
    end
  end

  @spec apply_update(Changeset.t(), [attribute]) :: Changeset.t()
  defp apply_update(%Changeset{valid?: false} = changeset, _update_attributes), do: changeset

  defp apply_update(changeset, update_attributes) when update_attributes == [],
    do: changeset

  defp apply_update(changeset, update_attributes) do
    attributes =
      changeset |> Changeset.fetch_field!(:attributes)

    attributes = Map.merge(attributes, Map.new(update_attributes))

    Changeset.put_change(changeset, :attributes, attributes)
  end
end
