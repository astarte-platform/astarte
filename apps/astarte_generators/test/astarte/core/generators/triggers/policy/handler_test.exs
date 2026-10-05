#
# This file is part of Astarte.
#
# Copyright 2025 - 2026 Clea Srl
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

defmodule Astarte.Core.Generators.Triggers.Policy.HandlerTest do
  @moduledoc """
  Tests for Astarte Triggers Policy Handler generator.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.Generators.Triggers.Policy.Handler

  alias Astarte.Core.Triggers.Policy.Handler

  @moduletag :trigger
  @moduletag :policy
  @moduletag :handler

  @doc false
  describe "triggers policy handler generator" do
    @describetag :success
    @describetag :ut

    property "generates handlers accepted by the Core changeset" do
      check all handler <- handler() do
        params = handler |> Jason.encode!() |> Jason.decode!()

        assert %Ecto.Changeset{valid?: true} = Handler.changeset(%Handler{}, params)
        refute MapSet.new([]) == handler |> Handler.error_set()
      end
    end
  end
end
