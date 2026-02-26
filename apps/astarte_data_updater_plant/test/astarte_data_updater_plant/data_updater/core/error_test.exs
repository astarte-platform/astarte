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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.ErrorTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device

  use Astarte.Cases.DataUpdater

  use Astarte.Generators.Utilities.ParamsGen
  use ExUnitProperties
  use Mimic

  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.Error
  alias Astarte.DataUpdaterPlant.DataUpdater.Impl

  import Astarte.InterfaceUpdateGenerators

  describe "handle_error/2" do
    property "handle_error/2 resets connection and discards the message, updating stats by default",
             context do
      %{state: state, interfaces: interfaces} = context

      check all context <- gen_context(state, interfaces),
                error <- gen_error(),
                max_runs: 10 do
        set_expectations(context, error)
        assert ^state = handle_error(context, error)
      end
    end

    property "handle_error/2 resets connection and discards the message, not updating stats if told to",
             context do
      %{state: state, interfaces: interfaces} = context

      check all context <- gen_context(state, interfaces),
                error <- gen_error(),
                max_runs: 10 do
        opts = [update_stats: false]
        set_expectations(context, error, opts)

        assert ^state = handle_error(context, error, opts)
      end
    end
  end

  defp handle_error(context, error, opts \\ []) do
    assert {:discard, _reason, new_state, {:continue, continue_arg}} =
             Error.handle_error(context, error, opts)

    assert {:ok, new_state} = Impl.handle_continue(continue_arg, new_state)
    new_state
  end

  defp set_expectations(context, error, opts \\ []) do
    %{
      state: state,
      interface: interface,
      path: path,
      timestamp: timestamp,
      payload: payload
    } = context

    %{
      error_name: error_name
    } = error

    update_stats = Keyword.get(opts, :update_stats, true)
    ask_clean_session = Keyword.get(opts, :ask_clean_session, true)
    execute_error_triggers = Keyword.get(opts, :execute_error_triggers, true)

    if ask_clean_session,
      do: expect(Core.Device, :ask_clean_session, fn ^state, ^timestamp -> {:ok, state} end)

    if execute_error_triggers,
      do:
        expect(
          Core.Trigger,
          :execute_device_error_triggers,
          fn ^state, ^error_name, error_metadata, ^timestamp ->
            expected_interface = inspect(interface)
            expected_path = inspect(path)
            expected_payload = Base.encode64(payload)

            assert %{
                     "interface" => ^expected_interface,
                     "path" => ^expected_path,
                     "base64_payload" => ^expected_payload
                   } = error_metadata

            {:ok, state}
          end
        )

    if update_stats,
      do:
        expect(Core.DataHandler, :update_stats, fn ^state, ^interface, nil, ^path, ^payload ->
          state
        end)
  end

  defp gen_context(state, interfaces) do
    gen all interface <- member_of(interfaces),
            mapping <- member_of(interface.mappings),
            path <- path_from_endpoint(mapping.endpoint),
            timestamp <- repeatedly(&DateTime.utc_now/0),
            payload <- binary() do
      %{
        state: state,
        interface: interface,
        path: path,
        timestamp: timestamp,
        payload: payload
      }
    end
  end

  defp gen_error(params \\ []) do
    params gen all message <- string(:utf8),
                   tag <- string(:utf8),
                   error <- atom(:alphanumeric),
                   error_name <- string(:utf8),
                   params: params do
      %{
        message: message,
        logger_metadata: [tag: tag],
        error: error,
        error_name: error_name
      }
    end
  end
end
