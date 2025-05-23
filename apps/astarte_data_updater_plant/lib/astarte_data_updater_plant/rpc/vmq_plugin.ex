#
# This file is part of Astarte.
#
# Copyright 2018 - 2023 SECO Mind Srl
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

defmodule Astarte.DataUpdaterPlant.RPC.VMQPlugin do
  @moduledoc """
  This module sends RPC to VMQPlugin
  """

  @rpc_client Application.compile_env(
                :astarte_data_updater_plant,
                :vernemq_plugin_rpc_client,
                Astarte.DataUpdaterPlant.RPC.VMQPlugin.Client
              )

  def publish(topic, payload, qos)
      when is_binary(topic) and is_binary(payload) and is_integer(qos) and qos >= 0 and qos <= 2 do
    with {:ok, tokens} <- split_topic(topic) do
      data = %{
        topic_tokens: tokens,
        payload: payload,
        qos: qos
      }

      @rpc_client.publish(data)
    end
  end

  def delete(realm_name, device_id) do
    data = %{
      realm_name: realm_name,
      device_id: device_id
    }

    @rpc_client.delete(data)
  end

  def disconnect(client_id, discard_state)
      when is_binary(client_id) and is_boolean(discard_state) do
    data = %{
      client_id: client_id,
      discard_state: discard_state
    }

    @rpc_client.disconnect(data)
  end

  defp split_topic(topic) do
    case String.split(topic, "/") do
      [] -> {:error, :empty_topic}
      tokens -> {:ok, tokens}
    end
  end
end
