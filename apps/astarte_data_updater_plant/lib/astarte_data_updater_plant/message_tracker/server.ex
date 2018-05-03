#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.DataUpdaterPlant.MessageTracker.Server do
  alias Astarte.DataUpdaterPlant.AMQPDataConsumer
  require Logger
  use GenServer

  @base_backoff 1000
  @random_backoff 9000

  def init(:ok) do
    {:ok, {:new, :queue.new(), %{}}}
  end

  def handle_call(:register_data_updater, from, {:new, queue, ids}) do
    monitor(from)
    {:reply, :ok, {:accepting, queue, ids}}
  end

  def handle_call(:register_data_updater, from, {_state, queue, ids}) do
    Logger.debug("Blocked data updater registration. Queue is #{inspect(queue)}.")

    {:noreply, {{:waiting_cleanup, from}, queue, ids}}
  end

  def handle_call({:can_process_message, message_id}, from, {:accepting, queue, ids} = s) do
    case :queue.peek(queue) do
      {:value, ^message_id} ->
        case Map.get(ids, message_id) do
          nil ->
            {:noreply, {{:waiting_delivery, from}, queue, ids}}

          {:requeued, _delivery_tag} ->
            {:noreply, {{:waiting_delivery, from}, queue, ids}}

          _ ->
            {:reply, true, s}
        end

      {:value, _} ->
        {:reply, false, s}

      :empty ->
        Logger.debug("#{inspect(message_id)} has not been tracked yet. Waiting.")
        {:noreply, {{:waiting_delivery, message_id, from}, queue, ids}}
    end
  end

  def handle_call({:ack_delivery, message_id}, _from, {:accepting, queue, ids}) do
    {{:value, ^message_id}, new_queue} = :queue.out(queue)
    {delivery_tag, new_ids} = Map.pop(ids, message_id)

    :ok = ack(delivery_tag)

    {:reply, :ok, {:accepting, new_queue, new_ids}}
  end

  def handle_call({:discard, message_id}, _from, {:accepting, queue, ids}) do
    {{:value, ^message_id}, new_queue} = :queue.out(queue)
    {delivery_tag, new_ids} = Map.pop(ids, message_id)

    :ok = discard(delivery_tag)

    {:reply, :ok, {:accepting, new_queue, new_ids}}
  end

  def handle_cast(
        {:track_delivery, message_id, delivery_tag},
        {{:waiting_delivery, waiting_process}, queue, ids}
      ) do
    case Map.get(ids, message_id) do
      nil ->
        {new_queue, new_ids} = enqueue_message(queue, ids, message_id, delivery_tag)
        {:noreply, {{:waiting_delivery, waiting_process}, new_queue, new_ids}}

      {:requeued, _tag} ->
        new_ids = Map.put(ids, message_id, delivery_tag)

        if :queue.peek(queue) == {:value, message_id} do
          GenServer.reply(waiting_process, true)
          {:noreply, {:accepting, queue, new_ids}}
        else
          {:noreply, {{:waiting_delivery, waiting_process}, queue, new_ids}}
        end

      _ ->
        new_ids = Map.put(ids, message_id, delivery_tag)
        {:noreply, {{:waiting_delivery, waiting_process}, queue, new_ids}}
    end
  end

  def handle_cast(
        {:track_delivery, message_id, delivery_tag},
        {state, queue, ids}
      ) do
    unless Map.has_key?(ids, message_id) do
      {new_queue, new_ids} = enqueue_message(queue, ids, message_id, delivery_tag)
      {:noreply, {state, new_queue, new_ids}}
    else
      new_ids = Map.put(ids, message_id, delivery_tag)
      {:noreply, {state, queue, new_ids}}
    end
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, {state, queue, ids} = s) do
    Logger.warn("Crash detected. Reason: #{inspect(reason)}, state: #{inspect(s)}.")

    marked_ids =
      :queue.to_list(queue)
      |> List.foldl(%{}, fn item, acc ->
        delivery_tag = ids[item]
        :ok = requeue(delivery_tag)
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
        {:noreply, {:accepting, queue, marked_ids}}

      _ ->
        {:noreply, {:new, queue, marked_ids}}
    end
  end

  defp monitor({pid, _ref}) do
    Process.monitor(pid)
  end

  defp enqueue_message(queue, ids, message_id, delivery_tag) do
    new_ids = Map.put(ids, message_id, delivery_tag)
    new_queue = :queue.in(message_id, queue)
    {new_queue, new_ids}
  end

  defp requeue({:injected_msg, _ref}) do
    :ok
  end

  defp requeue(delivery_tag) when is_integer(delivery_tag) do
    AMQPDataConsumer.requeue(delivery_tag)
  end

  defp requeue({:requeued, delivery_tag}) when is_integer(delivery_tag) do
    # Do not try to requeue already requeued messages, otherwise channel will crash
    :ok
  end

  defp ack({:injected_msg, _ref}) do
    :ok
  end

  defp ack(delivery_tag) when is_integer(delivery_tag) do
    AMQPDataConsumer.ack(delivery_tag)
  end

  defp discard({:injected_msg, _ref}) do
    :ok
  end

  defp discard(delivery_tag) when is_integer(delivery_tag) do
    AMQPDataConsumer.discard(delivery_tag)
  end
end
