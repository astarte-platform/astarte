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

defmodule Astarte.AppEngine.API.Device.DeviceV2ReadingTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use ExUnitProperties

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.InterfaceValues

  import Astarte.Helpers.Device
  import Astarte.InterfaceValuesRetrievealGenerators

  setup_all :populate_interfaces

  describe "get_interface_values!/5" do
    property "allows downsampling individual datastreams", context do
      %{
        realm_name: realm_name,
        device: device,
        registered_paths: registered_paths,
        interfaces_with_data: interfaces_with_data
      } = context

      downsampable_interfaces =
        interfaces_with_data
        |> Enum.filter(&downsampable?/1)
        |> Enum.filter(&(&1.aggregation == :individual))

      downsampable_paths =
        downsampable_interfaces
        |> Enum.map(fn interface ->
          {interface, downsampable_paths(realm_name, interface, registered_paths)}
        end)
        |> Enum.reject(fn {_interface, paths} -> Enum.empty?(paths) end)
        |> Map.new()

      downsampable_interfaces = Map.keys(downsampable_paths)

      check all interface <- member_of(downsampable_interfaces),
                "/" <> path <- member_of(downsampable_paths[interface]),
                downsample_to <- integer(3..100),
                opts <- interface_values_options(downsample_to: downsample_to) do
        {:ok, %InterfaceValues{data: result}} =
          Device.get_interface_values!(
            realm_name,
            device.encoded_id,
            interface.name,
            path,
            opts
          )

        assert result_size(result) <= downsample_to
      end
    end

    property "allows downsampling object datastreams when all values are not nil", context do
      %{
        realm_name: realm_name,
        device: device,
        registered_paths: registered_paths,
        downsampable_object_interface: interface
      } = context

      interface_key = {interface.name, interface.major_version}
      paths = Map.fetch!(registered_paths, interface_key)

      object_keys =
        interface.mappings
        |> Enum.map(fn mapping -> mapping.endpoint |> String.split("/") |> List.last() end)

      check all "/" <> path <- member_of(paths),
                downsample_key <- member_of(object_keys),
                downsample_to <- integer(3..100),
                opts <-
                  interface_values_options(
                    downsample_to: downsample_to,
                    downsample_key: downsample_key
                  ) do
        {:ok, %InterfaceValues{data: result}} =
          Device.get_interface_values!(
            realm_name,
            device.encoded_id,
            interface.name,
            path,
            opts
          )

        assert result_size(result) <= downsample_to
      end
    end
  end

  property "allows restricting datastream data returned to an arbitrary timeframe", context do
    %{
      realm_name: realm_name,
      device: device,
      registered_paths: registered_paths,
      registered_timings: registered_timings,
      interfaces_with_data: interfaces
    } = context

    datastreams = interfaces |> Enum.filter(&(&1.type == :datastream))

    check all interface <- member_of(datastreams),
              "/" <> path <-
                member_of(registered_paths[{interface.name, interface.major_version}]),
              timings = registered_timings[{interface.name, interface.major_version}],
              since_or_after <- member_of([:since, :since_after]),
              lower_limit <- optional(timestamp_at_least(timings.initial_time)),
              to <- optional(timestamp_at_most(timings.last_time)),
              params = [{since_or_after, lower_limit}, to: to],
              opts <- interface_values_options(params, interface) do
      result =
        Device.get_interface_values!(
          realm_name,
          device.encoded_id,
          interface.name,
          path,
          opts
        )

      # If the API returns path not found, it means we have filtered out all values, so this is
      # a valid result
      timestamps =
        case result do
          {:ok, result} -> extract_timestamps(result, opts.format)
          {:error, :path_not_found} -> []
        end

      if opts[:since] != nil do
        assert Enum.all?(timestamps, &(!DateTime.before?(&1, lower_limit)))
      end

      if opts[:since_after] != nil do
        assert Enum.all?(timestamps, &DateTime.after?(&1, lower_limit))
      end

      if to != nil do
        assert Enum.all?(timestamps, &DateTime.before?(&1, to))
      end
    end
  end

  defp optional(gen), do: one_of([nil, gen])

  defp timestamp_at_least(datetime) do
    min = DateTime.to_unix(datetime)
    max = min + 500

    integer(min..max)
    |> map(&DateTime.from_unix!/1)
  end

  defp timestamp_at_most(datetime) do
    max = DateTime.to_unix(datetime)
    min = max - 500

    integer(min..max)
    |> map(&DateTime.from_unix!/1)
  end

  defp extract_timestamps(%InterfaceValues{data: data}, "structured"),
    do: Enum.map(data, &to_datetime(Map.fetch!(&1, "timestamp")))

  defp extract_timestamps(%InterfaceValues{metadata: metadata, data: data}, "table") do
    timestamp_index =
      metadata["columns"]["timestamp"] || flunk("no timestamp column in table result")

    Enum.map(data, &to_datetime(Enum.at(&1, timestamp_index)))
  end

  defp extract_timestamps(%InterfaceValues{data: %{"value" => data}}, "disjoint_tables")
       when is_list(data),
       do: Enum.map(data, fn [_value, timestamp] -> to_datetime(timestamp) end)

  defp extract_timestamps(%InterfaceValues{data: data}, "disjoint_tables")
       when is_map(data) do
    data
    |> Map.values()
    |> Enum.concat()
    |> Enum.map(fn [_value, timestamp] -> to_datetime(timestamp) end)
  end

  defp to_datetime(timestamp) when is_integer(timestamp),
    do: DateTime.from_unix!(timestamp, :millisecond)

  defp to_datetime(datetime) when is_struct(datetime, DateTime), do: datetime

  defp result_size(result) when is_list(result), do: Enum.count(result)
  defp result_size(%{"value" => result}), do: result_size(result)
  defp result_size(_single_result), do: 1
end
