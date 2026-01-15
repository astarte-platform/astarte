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

  import Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.Policy.ErrorKeyword
  alias Astarte.Core.Triggers.Policy.ErrorRange
  alias Astarte.Core.Triggers.Policy.Handler

  alias Astarte.Core.Generators.Triggers.Policy.ErrorKeyword, as: ErrorKeywordGenerator
  alias Astarte.Core.Generators.Triggers.Policy.Handler, as: HandlerGenerator

  alias Astarte.Utilities.Map, as: MapUtilities

  # \n: 10
  # @: 0x40
  @utf8_except_newline_and_atsign [0..9, 11..0x39, 0x41..0xD7FF, 0xE000..0x10FFFF]
  @utf8_except_newline [?@ | @utf8_except_newline_and_atsign]

  @any_error ErrorKeywordGenerator.any_error()

  @spec policy() :: StreamData.t(Policy.t())
  @spec policy(keyword :: keyword()) :: StreamData.t(Policy.t())
  def policy(params \\ []) do
    params gen all name <- name(),
                   maximum_capacity <- maximum_capacity(),
                   error_handlers <- error_handlers(),
                   retry_times <- retry_times(error_handlers),
                   event_ttl <- event_ttl(),
                   prefetch_count <- prefetch_count(),
                   params: params do
      fields =
        MapUtilities.clean(%{
          name: name,
          maximum_capacity: maximum_capacity,
          error_handlers: error_handlers,
          retry_times: retry_times,
          event_ttl: event_ttl,
          prefetch_count: prefetch_count
        })

      struct(Policy, fields)
    end
  end

  @doc """
  Convert this struct/stream to changes
  """
  @spec to_changes(Policy.t()) :: StreamData.t(map())
  def to_changes(data) when not is_struct(data, StreamData),
    do: data |> constant() |> to_changes()

  @spec to_changes(StreamData.t(Policy.t())) :: StreamData.t(map())
  def to_changes(gen) do
    gen all %Policy{
              name: name,
              maximum_capacity: maximum_capacity,
              error_handlers: error_handlers,
              retry_times: retry_times,
              event_ttl: event_ttl,
              prefetch_count: prefetch_count
            } <- gen,
            error_handlers <-
              error_handlers
              |> Enum.map(&HandlerGenerator.to_changes(constant(&1)))
              |> fixed_list() do
      MapUtilities.clean(%{
        name: name,
        maximum_capacity: maximum_capacity,
        error_handlers: error_handlers,
        retry_times: retry_times,
        event_ttl: event_ttl,
        prefetch_count: prefetch_count
      })
    end
  end

  defp name do
    gen all first <- string(@utf8_except_newline_and_atsign, length: 1),
            rest <- string(@utf8_except_newline, max_length: 127) do
      first <> rest
    end
  end

  defp maximum_capacity, do: integer(1..1_000_000)

  defp event_ttl, do: one_of([integer(1..86_400), nil])

  defp prefetch_count, do: one_of([integer(1..300), nil])

  defp error_handlers do
    # TODO try to use
    # https://hexdocs.pm/elixir/Stream.html#scan/3
    gen all handlers <- list_of(HandlerGenerator.handler(), min_length: 1) do
      handlers |> Enum.sort(&sort_handlers/2) |> filter_handle([], MapSet.new())
    end
  end

  defp retry_times(error_handlers) do
    case Enum.all?(error_handlers, &Handler.discards?/1) do
      true -> constant(nil)
      false -> integer(1..100)
    end
  end

  #
  # Utilities
  defp sort_handlers(
         %Handler{on: %ErrorKeyword{}},
         %Handler{on: %ErrorRange{}}
       ),
       do: true

  defp sort_handlers(
         %Handler{on: %ErrorRange{}},
         %Handler{on: %ErrorKeyword{}}
       ),
       do: false

  defp sort_handlers(_, _), do: true

  defp filter_handle([], acc, _used_codes), do: acc

  @empty_mapset MapSet.new([])
  defp filter_handle(
         [%Handler{on: %ErrorKeyword{keyword: @any_error}} = handler | _handlers],
         acc,
         used_codes
       )
       when used_codes == @empty_mapset,
       do: [handler | acc]

  defp filter_handle(
         [%Handler{on: %ErrorKeyword{keyword: keyword}} = handler | handlers],
         acc,
         used_codes
       ) do
    codes = error_set(keyword)

    case MapSet.disjoint?(codes, used_codes) do
      true -> filter_handle(handlers, [handler | acc], MapSet.union(codes, used_codes))
      false -> filter_handle(handlers, acc, used_codes)
    end
  end

  defp filter_handle(
         [%Handler{on: %ErrorRange{error_codes: error_codes}} = handler | handlers],
         acc,
         used_codes
       ) do
    available_error_codes = MapSet.difference(MapSet.new(error_codes), used_codes)
    available_error_codes_list = available_error_codes |> MapSet.to_list()

    case available_error_codes_list do
      [] ->
        filter_handle(handlers, acc, used_codes)

      _other ->
        handler = %Handler{handler | on: %ErrorRange{error_codes: available_error_codes_list}}
        filter_handle(handlers, [handler | acc], MapSet.union(available_error_codes, used_codes))
    end
  end

  defp error_set(keyword) do
    %Handler{on: %ErrorKeyword{keyword: keyword}}
    |> Handler.error_set()
  end
end
