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

  def init(:ok) do
    {:ok, {:new, :queue.new(), %{}, nil}}
  end

  def handle_call(:register_data_updater, {pid, _ref}, {:new, queue, ids, _}) do
    Process.monitor(pid)
    {:reply, :ok, {:accepting, queue, ids, nil}}
  end

  def handle_call(:register_data_updater, from, {state, queue, ids, _}) do
    Logger.debug("Blocked data updater registration. Queue is #{inspect(queue)}.")

    {:noreply, {state, queue, ids, from}}
  end

  def handle_call({:can_process_message, message_id}, from, {:accepting, queue, ids, pending} = s) do
    case :queue.peek(queue) do
      {:value, ^message_id} ->
        {:reply, true, s}

      {:value, _} ->
        {:reply, false, s}

      :empty ->
        Logger.debug("#{inspect(message_id)} has not been tracked yet. Waiting.")
        {:noreply, {{:accepting_waiting, message_id, from}, queue, ids, pending}}
    end
  end

  def handle_call({:ack_delivery, message_id}, _from, {:accepting, queue, ids, pending}) do
    {{:value, ^message_id}, new_queue} = :queue.out(queue)
    {delivery_tag, new_ids} = Map.pop(ids, message_id)

    unless match?({:injected_msg, _ref}, delivery_tag) do
      :ok = AMQPDataConsumer.ack(delivery_tag)
    end

    {:reply, :ok, {:accepting, new_queue, new_ids, pending}}
  end

  def handle_call({:discard, message_id}, _from, {:accepting, queue, ids, pending}) do
    {{:value, ^message_id}, new_queue} = :queue.out(queue)
    {delivery_tag, new_ids} = Map.pop(ids, message_id)

    unless match?({:injected_msg, _ref}, delivery_tag) do
      :ok = AMQPDataConsumer.discard(delivery_tag)
    end

    {:reply, :ok, {:accepting, new_queue, new_ids, pending}}
  end

  def handle_cast(
        {:track_delivery, message_id, delivery_tag, _redelivered},
        {{:cleanup, peek}, queue, ids, pending}
      )
      when message_id != peek do
    new_ids = Map.put(ids, message_id, delivery_tag)

    unless match?({:injected_msg, _ref}, delivery_tag) do
      :ok = AMQPDataConsumer.requeue(delivery_tag)
    end

    {:noreply, {{:cleanup, peek}, queue, new_ids, pending}}
  end

  def handle_cast(
        {:track_delivery, message_id, delivery_tag, redelivered},
        {{:cleanup, _peek}, queue, ids, nil}
      ) do
    handle_cast({:track_delivery, message_id, delivery_tag, redelivered}, {:new, queue, ids, nil})
  end

  def handle_cast(
        {:track_delivery, message_id, delivery_tag, redelivered},
        {{:cleanup, _peek}, queue, ids, pending}
      ) do
    next_state =
      handle_cast(
        {:track_delivery, message_id, delivery_tag, redelivered},
        {:accepting, queue, ids, pending}
      )

    Logger.debug("Ready to accept again incoming data")
    {pid, _ref} = pending
    Process.monitor(pid)
    GenServer.reply(pending, :ok)

    next_state
  end

  def handle_cast(
        {:track_delivery, message_id, delivery_tag, redelivered},
        {{:accepting_waiting, check_delivery, from}, queue, ids, pending}
      ) do
    next_state =
      handle_cast(
        {:track_delivery, message_id, delivery_tag, redelivered},
        {:accepting, queue, ids, pending}
      )

    Logger.debug("Received msg #{inspect(delivery_tag)}. Ready to get back to normal flow again.")

    if delivery_tag == check_delivery do
      GenServer.reply(from, true)
    else
      GenServer.reply(from, false)
    end

    next_state
  end

  def handle_cast(
        {:track_delivery, message_id, delivery_tag, redelivered},
        {state, queue, ids, pending}
      ) do
    new_ids = Map.put(ids, message_id, delivery_tag)

    cond do
      not redelivered ->
        new_queue = :queue.in(message_id, queue)
        {:noreply, {state, new_queue, new_ids, pending}}

      :queue.member(message_id, queue) ->
        Logger.debug("Duplicated message in queue detected: #{inspect(message_id)}")
        new_queue = :queue.in({:duplicated_delivery, message_id}, queue)
        {:noreply, {state, new_queue, new_ids, pending}}

      true ->
        new_queue = :queue.in(message_id, queue)
        {:noreply, {state, new_queue, new_ids, pending}}
    end
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, {_state, queue, ids, pending} = s) do
    Logger.warn("Crash detected. Reason: #{inspect(reason)}, state: #{inspect(s)}.")

    {next_state, new_queue} =
      case :queue.peek(queue) do
        :empty ->
          {:new, queue}

        {:value, peek} ->
          new_queue = reject_all(queue, ids)
          {{:cleanup, peek}, new_queue}
      end

    case pending do
      {pid, _ref} ->
        Logger.debug("Ready soon to process messages again.")
        Process.monitor(pid)
        GenServer.reply(pending, :ok)
        {:noreply, {:accepting, new_queue, ids, nil}}

      nil ->
        {:noreply, {next_state, new_queue, ids, nil}}
    end
  end

  defp reject_all(queue, ids) do
    case :queue.out(queue) do
      {{:value, message_id}, new_queue} ->
        delivery_tag = ids[message_id]

        unless match?({:injected_msg, _ref}, delivery_tag) do
          :ok = AMQPDataConsumer.requeue(delivery_tag)
        end

        reject_all(new_queue, ids)

      {:empty, new_queue} ->
        new_queue
    end
  end
end
