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

defmodule Astarte.Core.Generators.Triggers.Policy do
  @moduledoc """
  This module provides generators for Astarte Policy structs.

  See https://docs.astarte-platform.org/astarte/latest/040-interface_schema.html#mapping
  """

  use ExUnitProperties

  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.Policy.ErrorKeyword
  alias Astarte.Core.Triggers.Policy.ErrorRange
  alias Astarte.Core.Triggers.Policy.Handler

  @spec policy :: StreamData.t(Policy.t())
  def policy do
    gen all retry_times <- integer(1..100),
            fields <-
              optional_map(
                %{
                  name: policy_name(),
                  error_handlers: policy_handlers(),
                  maximum_capacity: integer(1..1_000_000),
                  event_ttl: integer(1..86_400),
                  prefetch_count: integer(1..300)
                },
                [:event_ttl, :prefetch_count]
              ) do
      retry_times =
        case Enum.all?(fields.error_handlers, &Handler.discards?/1) do
          true -> nil
          false -> retry_times
        end

      fields = fields |> Map.put(:retry_times, retry_times)
      struct(Policy, fields)
    end
  end

  defp policy_name do
    string(:utf8, min_length: 1, max_length: 128)
    |> filter(fn <<first::utf8, _rest::binary>> -> first != ?@ end)
  end

  defp policy_handlers do
    gen all keywords <-
              one_of([
                constant(["any_error"]),
                uniq_list_of(member_of(["client_error", "server_error"]), max_length: 2)
              ]),
            error_codes <- policy_handler_error_codes_from_used_keywords(keywords) do
      total_handlers = length(keywords) + length(error_codes)
      strategies = member_of(["discard", "retry"]) |> Enum.take(total_handlers)

      keywords =
        keywords
        |> Enum.map(&%ErrorKeyword{keyword: &1})

      ranges = error_codes |> Enum.map(&%ErrorRange{error_codes: &1})

      Enum.concat(keywords, ranges)
      |> Enum.shuffle()
      |> Enum.zip(strategies)
      |> Enum.map(fn {error_type, strategy} ->
        %Handler{on: error_type, strategy: strategy}
      end)
    end
  end

  defp policy_handler_error_codes_from_used_keywords(keywords) do
    all_error_codes = 400..599 |> MapSet.new()

    used_codes =
      keywords
      |> Enum.map(&%Handler{on: %ErrorKeyword{keyword: &1}})
      |> Enum.map(&Handler.error_set/1)
      |> Enum.concat()
      |> MapSet.new()

    allowed_codes = MapSet.difference(all_error_codes, used_codes)

    case Enum.empty?(allowed_codes) do
      true ->
        constant([])

      false ->
        gen all codes <- list_of(member_of(allowed_codes), min_length: 1) do
          # avoid uniq_list_of because of the small sample size
          codes = Enum.uniq(codes)
          gen_policy_handler_error_codes(codes)
        end
    end
  end

  defp gen_policy_handler_error_codes([]), do: []

  defp gen_policy_handler_error_codes(l) do
    chunk_length = :rand.uniform(length(l))
    {chunk, rest} = l |> Enum.shuffle() |> Enum.split(chunk_length)
    [chunk | gen_policy_handler_error_codes(rest)]
  end
end
