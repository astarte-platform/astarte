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

defmodule Astarte.Core.Generators.Triggers.Policy.HandlerTest do
  @moduledoc """
  Tests for Astarte Triggers Policy Handler generator.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.Generators.Triggers.Policy.Handler, as: HandlerGenerator
  alias Astarte.Core.Triggers.Policy.Handler

  @moduletag :trigger
  @moduletag :policy
  @moduletag :handler

  @doc false
  describe "triggers policy handler generator" do
    @describetag :success
    @describetag :ut

    property "validate triggers policy handler using to_changes (gen)" do
      gen_handler_changes = HandlerGenerator.handler() |> HandlerGenerator.to_changes()

      check all changes <- gen_handler_changes,
                changeset = Handler.changeset(%Handler{}, changes) do
        assert changeset.valid?, "Invalid handler: #{inspect(changeset.errors)}"
      end
    end

    property "validate triggers policy handler using to_changes (struct)" do
      check all handler <- HandlerGenerator.handler(),
                changes <- HandlerGenerator.to_changes(handler),
                changeset = Handler.changeset(%Handler{}, changes) do
        assert changeset.valid?, "Invalid handler: #{inspect(changeset.errors)}"
      end
    end

    property "validate triggers policy handler error_set" do
      check all handler <- HandlerGenerator.handler() do
        refute MapSet.new([]) == handler |> Handler.error_set()
      end
    end
  end
end
