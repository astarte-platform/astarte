#
# This file is part of Astarte.
#
# Copyright 2018 - 2025 SECO Mind Srl
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

defmodule Astarte.DataUpdaterPlant.MessageTracker.Server do
  require Logger
  use GenServer

  @base_backoff 1000
  @random_backoff 9000

  # TODO: this should probably be a :gen_statem so we can simplify state data

  def start_link(args) do
    name = Keyword.fetch!(args, :name)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  @impl GenServer
  def init(args) do
    acknowledger = Keyword.fetch!(args, :acknowledger)
    Process.flag(:trap_exit, true)
    {:ok, {:new, :queue.new(), %{}, acknowledger}}
  end

  @impl GenServer
  def handle_call(:register_data_updater, from, {:new, queue, ids, acknowledger}) do
    monitor(from)
    {:reply, :ok, {:accepting, queue, ids, acknowledger}}
  end

  @impl GenServer
  def handle_call(:register_data_updater, from, {_state, queue, ids, acknowledger}) do
    Logger.debug("Blocked data updater registration. Queue is #{inspect(queue)}.")

    {:noreply, {{:waiting_cleanup, from}, queue, ids, acknowledger}}
  end

  @impl GenServer
  def handle_call(
        {:can_process_message, message_id},
        from,
        {:accepting, queue, ids, acknowledger} = s
      ) do
    case :queue.peek(queue) do
      {:value, ^message_id} ->
        case Map.get(ids, message_id) do
          nil ->
            {:noreply, {{:waiting_delivery, from}, queue, ids, acknowledger}}

          {:requeued, _delivery_tag} ->
            {:noreply, {{:waiting_delivery, from}, queue, ids, acknowledger}}

          _ ->
            {:reply, true, s}
        end

      {:value, _} ->
        {:reply, false, s}

      :empty ->
        Logger.debug("#{inspect(message_id)} has not been tracked yet. Waiting.")
        {:noreply, {{:waiting_delivery, message_id, from}, queue, ids, acknowledger}}
    end
  end

  @impl GenServer
  def handle_call({:ack_delivery, message_id}, _from, {:accepting, queue, ids, acknowledger}) do
    {{:value, ^message_id}, new_queue} = :queue.out(queue)
    {delivery_tag, new_ids} = Map.pop(ids, message_id)

    :ok = ack(acknowledger, delivery_tag)

    {:reply, :ok, {:accepting, new_queue, new_ids, acknowledger}}
  end

  @impl GenServer
  def handle_call({:discard, message_id}, _from, {:accepting, queue, ids, acknowledger}) do
    {{:value, ^message_id}, new_queue} = :queue.out(queue)
    {delivery_tag, new_ids} = Map.pop(ids, message_id)

    :ok = discard(acknowledger, delivery_tag)

    {:reply, :ok, {:accepting, new_queue, new_ids, acknowledger}}
  end

  @impl GenServer
  def handle_call(:deactivate, _from, {state, queue, ids, _acknowledger} = s) do
    cond do
      not :queue.is_empty(queue) ->
        # We are in a dirty state, so we will not deactivate and we return an error
        Logger.warning("Refusing to deactivate MessageTracker with non-empty queue.",
          tag: "message_tracker_deactivate_failed"
        )

        {:reply, {:error, :deactivate_failed}, s}

      ids != %{} ->
        # We are in a dirty state, so we will not deactivate and we return an error
        Logger.warning("Refusing to deactivate MessageTracker with non-empty ids.",
          tag: "message_tracker_deactivate_failed"
        )

        {:reply, {:error, :deactivate_failed}, s}

      state != :accepting ->
        # We are in a dirty state, so we will not deactivate and we return an error
        Logger.warning("Refusing to deactivate MessageTracker not in :accepting state.",
          tag: "message_tracker_deactivate_failed"
        )

        {:reply, {:error, :deactivate_failed}, s}

      true ->
        # Everything is clean, we can deactivate
        {:stop, :normal, :ok, s}
    end
  end

  @impl GenServer
  def handle_cast(
        {:track_delivery, message_id, delivery_tag},
        {{:waiting_delivery, waiting_process}, queue, ids, acknowledger}
      ) do
    case Map.get(ids, message_id) do
      nil ->
        {new_queue, new_ids} = enqueue_message(queue, ids, message_id, delivery_tag)
        {:noreply, {{:waiting_delivery, waiting_process}, new_queue, new_ids, acknowledger}}

      {:requeued, _tag} ->
        new_ids = Map.put(ids, message_id, delivery_tag)

        if :queue.peek(queue) == {:value, message_id} do
          GenServer.reply(waiting_process, true)
          {:noreply, {:accepting, queue, new_ids, acknowledger}}
        else
          {:noreply, {{:waiting_delivery, waiting_process}, queue, new_ids, acknowledger}}
        end

      _ ->
        new_ids = Map.put(ids, message_id, delivery_tag)
        {:noreply, {{:waiting_delivery, waiting_process}, queue, new_ids, acknowledger}}
    end
  end

  @impl GenServer
  def handle_cast(
        {:track_delivery, message_id, delivery_tag},
        {state, queue, ids, acknowledger}
      ) do
    unless Map.has_key?(ids, message_id) do
      {new_queue, new_ids} = enqueue_message(queue, ids, message_id, delivery_tag)
      {:noreply, {state, new_queue, new_ids, acknowledger}}
    else
      new_ids = Map.put(ids, message_id, delivery_tag)
      {:noreply, {state, queue, new_ids, acknowledger}}
    end
  end

  @impl GenServer
  def handle_info(
        {:DOWN, _, :process, _pid, reason},
        {state, queue, ids, acknowledger} = s
      ) do
    Logger.warning("Crash detected. Reason: #{inspect(reason)}, state: #{inspect(s)}.",
      tag: "data_upd_crash_detected"
    )

    # TODO: add realm to labels once it is made available to the module
    :telemetry.execute([:astarte, :data_updater_plant, :data_updater, :detected_crash], %{}, %{})

    marked_ids =
      :queue.to_list(queue)
      |> List.foldl(%{}, fn item, acc ->
        delivery_tag = ids[item]
        :ok = requeue(acknowledger, delivery_tag)
        Map.put(acc, item, {:requeued, delivery_tag})
      end)

    unless :queue.is_empty(queue) do
      :rand.uniform(@random_backoff)
      |> Kernel.+(@base_backoff)
      |> :timer.sleep()
    end

    case state do
      {:waiting_cleanup, waiting_process} ->
        monitor(waiting_process)
        GenServer.reply(waiting_process, :ok)
        {:noreply, {:accepting, queue, marked_ids, acknowledger}}

      _ ->
        {:noreply, {:new, queue, marked_ids, acknowledger}}
    end
  end

  @impl GenServer
  def handle_info(
        {:EXIT, _pid, {:name_conflict, {_name, _value}, _registry, _winning_pid}},
        state
      ) do
    _ =
      Logger.warning(
        "Received a :name_confict signal from the outer space, maybe a netsplit occurred? Gracefully shutting down.",
        tag: "name_conflict"
      )

    {:stop, :normal, state}
  end

  defp monitor({pid, _ref}) do
    Process.monitor(pid)
  end

  defp enqueue_message(queue, ids, message_id, delivery_tag) do
    new_ids = Map.put(ids, message_id, delivery_tag)
    new_queue = :queue.in(message_id, queue)
    {new_queue, new_ids}
  end

  defp requeue(_acknowledger, {:injected_msg, _ref}) do
    :ok
  end

  defp requeue(acknowledger, delivery_tag) when is_integer(delivery_tag) do
    Logger.debug("Going to requeue #{inspect(delivery_tag)}")
    GenServer.call(acknowledger, {:requeue, delivery_tag})
  end

  defp requeue(_acknowledger, {:requeued, delivery_tag}) when is_integer(delivery_tag) do
    # Do not try to requeue already requeued messages, otherwise channel will crash
    :ok
  end

  defp ack(_acknowledger, {:injected_msg, _ref}) do
    :ok
  end

  defp ack(acknowledger, delivery_tag) when is_integer(delivery_tag) do
    Logger.debug("Going to ack #{inspect(delivery_tag)}")
    GenServer.call(acknowledger, {:ack, delivery_tag})
  end

  defp discard(_acknowledger, {:injected_msg, _ref}) do
    :ok
  end

  defp discard(acknowledger, delivery_tag) when is_integer(delivery_tag) do
    Logger.debug("Going to discard #{inspect(delivery_tag)}")
    GenServer.call(acknowledger, {:discard, delivery_tag})
  end
end
