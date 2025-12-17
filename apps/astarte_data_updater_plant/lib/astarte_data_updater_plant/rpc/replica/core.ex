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

defmodule Astarte.DataUpdaterPlant.RPC.Replica.Core do
  alias Astarte.Events.Triggers

  @doc """
    `GenServer.multi_call/4` implementation made to work with pids instead of
    nodes, so that it also works on test environments where the current node is
    `:nonode@nohost`
  """
  @spec multi_call([GenServer.server()], term(), timeout()) ::
          {replies :: [{GenServer.server(), term()}], bad_nodes :: [GenServer.server()]}
  def multi_call(replicas \\ [self()], request, timeout \\ :infinity) do
    # TODO: use a proper asynchronous call. Using Tasks inside a GenServer is curesd
    results =
      replicas
      |> Enum.map(&safe_call(&1, request, timeout))

    {ok, errors} = Enum.split_with(results, fn {tag, _} -> tag == :ok end)
    ok = ok |> Enum.map(fn {:ok, result} -> result end)
    errors = errors |> Enum.map(fn {:error, result} -> result end)
    {ok, errors}
  end

  def handle_result({replies, _bad_nodes}) do
    # we don't care about bad nodes, as we are eventually consistent anyway
    replies
    |> Enum.find_value(:ok, fn {_node, reply} -> reply != :ok && reply end)
  end

  def install_trigger(realm_name, tagged_simple_trigger, target, policy, data) do
    Triggers.install_trigger(realm_name, tagged_simple_trigger, target, policy, data)
  end

  def delete_trigger(realm_name, trigger_id, tagged_simple_trigger, data) do
    Triggers.delete_trigger(realm_name, trigger_id, tagged_simple_trigger, data)
  end

  defp safe_call(server, request, timeout) do
    try do
      resp = GenServer.call(server, request, timeout)
      {:ok, {server, resp}}
    catch
      :exit, _ -> {:error, server}
      _ -> {:error, server}
    end
  end
end
