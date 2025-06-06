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
  use ExUnitProperties
  use Astarte.Generators.Utilities.ParamsGen
  use Mimic

  alias Astarte.DataUpdaterPlant.DataUpdater.Core.Error
  alias Astarte.DataUpdaterPlant.MessageTracker
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataUpdaterPlant.DataUpdater.Core

  import Astarte.Helpers.DataUpdater
  import Astarte.InterfaceUpdateGenerators

  setup_all %{realm_name: realm_name, device: device} do
    setup_data_updater(realm_name, device.encoded_id)
    state = DataUpdater.dump_state(realm_name, device.encoded_id)

    %{state: state}
  end

  describe "handle_error/2" do
    property "handle_error/2 resets connection and discards the message, updating stats by default",
             context do
      %{state: state, interfaces: interfaces} = context

      check all context <- gen_context(state, interfaces),
                error <- gen_error() do
        set_expectations(context, error)
        assert ^state = Error.handle_error(context, error)
      end
    end

    property "handle_error/2 resets connection and discards the message, not updating stats if told to",
             context do
      %{state: state, interfaces: interfaces} = context

      check all context <- gen_context(state, interfaces),
                error <- gen_error() do
        opts = [update_stats: false]
        set_expectations(context, error, opts)

        assert ^state = Error.handle_error(context, error, opts)
      end
    end
  end

  defp set_expectations(context, error, opts \\ []) do
    %{
      state: state,
      interface: interface,
      message_id: message_id,
      path: path,
      timestamp: timestamp,
      payload: payload
    } = context

    %{
      error_name: error_name
    } = error

    message_tracker = state.message_tracker
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

    expect(MessageTracker, :discard, fn ^message_tracker, ^message_id -> :ok end)
  end

  defp gen_context(state, interfaces) do
    gen all interface <- member_of(interfaces),
            message_id <- repeatedly(&gen_message_id/0),
            mapping <- member_of(interface.mappings),
            path <- path_from_endpoint(mapping.endpoint),
            timestamp <- repeatedly(&DateTime.utc_now/0),
            payload <- binary() do
      %{
        state: state,
        interface: interface,
        message_id: message_id,
        path: path,
        timestamp: timestamp,
        payload: payload
      }
    end
  end

  defp gen_error(params \\ []) do
    params gen all message <- string(:utf8),
                   tag <- string(:utf8),
                   error_name <- string(:utf8),
                   params: params do
      %{
        message: message,
        logger_metadata: [tag: tag],
        error_name: error_name
      }
    end
  end

  defp gen_message_id, do: :erlang.unique_integer([:monotonic]) |> Integer.to_string()
end
