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
#

defmodule Astarte.Core.Generators.Triggers.Policy.ErrorRangeTest do
  @moduledoc """
  Tests for Astarte Triggers Policy ErrorRange generator.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.Generators.Triggers.Policy.ErrorRange, as: ErrorRangeGenerator
  alias Astarte.Core.Triggers.Policy.ErrorRange
  alias Ecto.Changeset

  @moduletag :trigger
  @moduletag :policy
  @moduletag :error_range

  # ? TODO move validate to a fixture file and make it generic
  defp validation_fixture(_context) do
    {
      :ok,
      validate: fn %ErrorRange{} = error_range ->
        error_range
        |> Changeset.change()
        |> ErrorRange.validate()
      end
    }
  end

  @doc """
  Property test for Astarte Triggers Policy ErrorRange generator.
  """
  describe "triggers policy error_range generator" do
    @describetag :success
    @describetag :ut

    setup :validation_fixture

    property "validate triggers policy error_range using Changeset", %{validate: validate} do
      check all(
              error_range <- ErrorRangeGenerator.error_range(),
              changeset = validate.(error_range)
            ) do
        assert changeset.valid?, "Invalid error_range: #{inspect(changeset.errors)}"
      end
    end
  end
end
