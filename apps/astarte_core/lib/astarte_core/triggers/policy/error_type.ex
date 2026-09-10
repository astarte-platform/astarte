#
# This file is part of Astarte.
#
# Copyright 2022 SECO Mind srl
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

defmodule Astarte.Core.Triggers.Policy.ErrorType do
  @moduledoc """
  Ecto type for trigger policy error types.
  """

  use Ecto.Type
  alias Astarte.Core.Triggers.Policy

  @type t :: %{}

  # a Json
  def type, do: :map

  def cast(error_type) when is_binary(error_type) do
    EctoMorph.generate_changeset(%{keyword: error_type}, Policy.ErrorKeyword)
    |> Policy.ErrorKeyword.validate()
    |> EctoMorph.into_struct()
    |> case do
      {:ok, struct} -> {:ok, struct}
      # returning changeset.errors ensures the error
      # goes on the parent changeset.
      {:error, changeset} -> {:error, changeset.errors}
    end
  end

  def cast(%{"keyword" => error_type}) do
    EctoMorph.generate_changeset(%{keyword: error_type}, Policy.ErrorKeyword)
    |> Policy.ErrorKeyword.validate()
    |> EctoMorph.into_struct()
    |> case do
      {:ok, struct} -> {:ok, struct}
      # returning changeset.errors ensures the error
      # goes on the parent changeset.
      {:error, changeset} -> {:error, changeset.errors}
    end
  end

  def cast(error_type) when is_list(error_type) do
    EctoMorph.generate_changeset(%{error_codes: error_type}, Policy.ErrorRange)
    |> Policy.ErrorRange.validate()
    |> EctoMorph.into_struct()
    |> case do
      {:ok, struct} -> {:ok, struct}
      # returning changeset.errors ensures the error
      # goes on the parent changeset.
      {:error, changeset} -> {:error, changeset.errors}
    end
  end

  def cast(%{"error_codes" => error_type}) do
    EctoMorph.generate_changeset(%{error_codes: error_type}, Policy.ErrorRange)
    |> Policy.ErrorRange.validate()
    |> EctoMorph.into_struct()
    |> case do
      {:ok, struct} -> {:ok, struct}
      # returning changeset.errors ensures the error
      # goes on the parent changeset.
      {:error, changeset} -> {:error, changeset.errors}
    end
  end

  def dump(error_type) when is_binary(error_type) do
    EctoMorph.cast_to_struct(%{keyword: error_type}, Policy.ErrorKeyword)
  end

  def dump(error_type) when is_list(error_type) do
    EctoMorph.cast_to_struct(%{error_codes: error_type}, Policy.ErrorRange)
  end

  def load(error_type) when is_binary(error_type) do
    EctoMorph.cast_to_struct(%{keyword: error_type}, Policy.ErrorKeyword)
  end

  def load(error_type) when is_list(error_type) do
    EctoMorph.cast_to_struct(%{error_codes: error_type}, Policy.ErrorRange)
  end
end
