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

defmodule Astarte.Core.Generators.Triggers.PolicyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.Generators.Triggers.Policy, as: PolicyGenerator
  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.Policy.ErrorKeyword
  alias Astarte.Core.Triggers.Policy.ErrorRange
  alias Astarte.Core.Triggers.Policy.Handler

  defp error_handler_changes_from_struct(handler) do
    %Handler{on: on, strategy: strategy} = handler

    random_element = :rand.uniform(2)

    on =
      case {on, random_element} do
        {%ErrorKeyword{keyword: keyword}, 1} -> keyword
        {%ErrorKeyword{keyword: keyword}, 2} -> %{"keyword" => keyword}
        {%ErrorRange{error_codes: error_codes}, 1} -> error_codes
        {%ErrorRange{error_codes: error_codes}, 2} -> %{"error_codes" => error_codes}
      end

    %{on: on, strategy: strategy}
  end

  defp changes_from_struct(policy) do
    %Policy{
      name: name,
      maximum_capacity: maximum_capacity,
      retry_times: retry_times,
      event_ttl: event_ttl,
      prefetch_count: prefetch_count,
      error_handlers: error_handlers
    } = policy

    error_handlers = Enum.map(error_handlers, &error_handler_changes_from_struct/1)

    %{
      name: name,
      maximum_capacity: maximum_capacity,
      retry_times: retry_times,
      event_ttl: event_ttl,
      prefetch_count: prefetch_count,
      error_handlers: error_handlers
    }
  end

  defp validation_helper(policy) do
    changes = changes_from_struct(policy)

    %Policy{}
    |> Policy.changeset(changes)
  end

  defp validation_fixture(_context), do: {:ok, validate: &validation_helper/1}

  @doc false
  describe "triggers policy generator" do
    @describetag :success
    @describetag :ut

    setup :validation_fixture

    property "generates valid policies", %{validate: validate} do
      check all error_range <- PolicyGenerator.policy(),
                changeset = validate.(error_range) do
        assert changeset.valid?, "Invalid policy: #{inspect(changeset.errors)}"
      end
    end
  end
end
