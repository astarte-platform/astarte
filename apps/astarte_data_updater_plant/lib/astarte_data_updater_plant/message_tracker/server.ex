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
    {:ok, {:new, :queue.new(), nil}}
  end

  def handle_call(:register_data_updater, {pid, _ref}, {:new, queue, _}) do
    Process.monitor(pid)
    {:reply, :ok, {:accepting, queue, nil}}
  end

  def handle_call(:register_data_updater, from, {state, queue, _}) do
    Logger.debug("Blocked data updater registration. Queue is #{inspect(queue)}.")

    {:noreply, {state, queue, from}}
  end

  def handle_call({:can_process_message, delivery_tag}, from, {:accepting, queue, pending} = s) do
    case :queue.peek(queue) do
      {:value, ^delivery_tag} ->
        {:reply, true, s}

      {:value, _} ->
        {:reply, false, s}

      :empty ->
        Logger.debug("#{inspect(delivery_tag)} has not been tracked yet. Waiting.")
        {:noreply, {{:accepting_waiting, delivery_tag, from}, queue, pending}}
    end
  end

  def handle_call({:ack_delivery, delivery_tag}, _from, {:accepting, queue, pending}) do
    {{:value, ^delivery_tag}, new_queue} = :queue.out(queue)

    unless match?({:injected_msg, _ref}, delivery_tag) do
      :ok = AMQPDataConsumer.ack(delivery_tag)
    end

    {:reply, :ok, {:accepting, new_queue, pending}}
  end

  def handle_call({:discard, delivery_tag}, _from, {:accepting, queue, pending}) do
    {{:value, ^delivery_tag}, new_queue} = :queue.out(queue)

    unless match?({:injected_msg, _ref}, delivery_tag) do
      :ok = AMQPDataConsumer.discard(delivery_tag)
    end

    {:reply, :ok, {:accepting, new_queue, pending}}
  end

  def handle_cast({:track_delivery, delivery_tag, _redelivered}, {{:cleanup, peek}, s})
      when delivery_tag != peek do
    unless match?({:injected_msg, _ref}, delivery_tag) do
      :ok = AMQPDataConsumer.requeue(delivery_tag)
    end

    {:noreply, s}
  end

  def handle_cast(
        {:track_delivery, delivery_tag, redelivered},
        {{:cleanup, _peek}, queue, nil}
      ) do
    handle_cast({:track_delivery, delivery_tag, redelivered}, {:new, queue, nil})
  end

  def handle_cast(
        {:track_delivery, delivery_tag, redelivered},
        {{:cleanup, _peek}, queue, pending}
      ) do
    next_state =
      handle_cast({:track_delivery, delivery_tag, redelivered}, {:accepting, queue, pending})

    Logger.debug("Ready to accept again incoming data")
    {pid, _ref} = pending
    Process.monitor(pid)
    GenServer.reply(pending, :ok)

    next_state
  end

  def handle_cast(
        {:track_delivery, delivery_tag, redelivered},
        {{:accepting_waiting, check_delivery, from}, queue, pending}
      ) do
    next_state =
      handle_cast({:track_delivery, delivery_tag, redelivered}, {:accepting, queue, pending})

    Logger.debug("Received msg #{inspect(delivery_tag)}. Ready to get back to normal flow again.")

    if delivery_tag == check_delivery do
      GenServer.reply(from, true)
    else
      GenServer.reply(from, false)
    end

    next_state
  end

  def handle_cast({:track_delivery, delivery_tag, redelivered}, {state, queue, pending}) do
    cond do
      not redelivered ->
        new_queue = :queue.in(delivery_tag, queue)
        {:noreply, {state, new_queue, pending}}

      :queue.member(delivery_tag, queue) ->
        Logger.debug("Duplicated message in queue detected: #{inspect(delivery_tag)}")
        new_queue = :queue.in({:duplicated_delivery, delivery_tag}, queue)
        {:noreply, {state, new_queue, pending}}

      true ->
        new_queue = :queue.in(delivery_tag, queue)
        {:noreply, {state, new_queue, pending}}
    end
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, {_state, queue, pending} = s) do
    Logger.warn("Crash detected. Reason: #{inspect(reason)}, state: #{inspect(s)}.")

    {next_state, new_queue} =
      case :queue.peek(queue) do
        :empty ->
          {:new, queue}

        {:value, {:duplicated_delivery, peek}} ->
          new_queue = reject_all(queue)
          {{:cleanup, peek}, new_queue}

        {:value, peek} ->
          new_queue = reject_all(queue)
          {{:cleanup, peek}, new_queue}
      end

    case pending do
      {pid, _ref} ->
        Logger.debug("Ready soon to process messages again.")
        Process.monitor(pid)
        GenServer.reply(pending, :ok)
        {:noreply, {:accepting, new_queue, nil}}

      nil ->
        {:noreply, {next_state, new_queue, nil}}
    end
  end

  defp reject_all(queue) do
    case :queue.out(queue) do
      {{:value, {:injected_msg, _ref}}, new_queue} ->
        reject_all(new_queue)

      {{:value, delivery_tag}, new_queue} ->
        :ok = AMQPDataConsumer.requeue(delivery_tag)
        reject_all(new_queue)

      {:empty, new_queue} ->
        new_queue
    end
  end
end
