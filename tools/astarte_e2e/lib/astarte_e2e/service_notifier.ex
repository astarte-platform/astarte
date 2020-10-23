#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
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

defmodule AstarteE2E.ServiceNotifier do
  @behaviour :gen_statem

  require Logger
  alias AstarteE2E.ServiceNotifier.{Email, Mailer}

  # API

  def start_link(args) do
    with {:ok, pid} <- :gen_statem.start_link({:local, __MODULE__}, __MODULE__, args, []) do
      Logger.info("Started process with pid #{inspect(pid)}.", tag: "process_started")

      {:ok, pid}
    end
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def notify_service_down(reason) do
    :gen_statem.call(__MODULE__, {:notify_service_down, reason})
  end

  def notify_service_up do
    :gen_statem.call(__MODULE__, :notify_service_up)
  end

  defp deliver(%Bamboo.Email{} = email) do
    with %Bamboo.Email{} = sent_email <- Mailer.deliver_later(email) do
      Logger.info("Service down. The user has been notified.", tag: "mail_sent")
      {:ok, sent_email}
    end
  end

  # Callbacks

  @impl true
  def callback_mode() do
    :state_functions
  end

  @impl true
  def init(_) do
    {:ok, :service_down, nil, [{:state_timeout, 60_000, nil}]}
  end

  def service_down(:state_timeout, _content, _data) do
    reason = "Timeout at startup"

    reason
    |> Email.service_down_email()
    |> deliver()

    :keep_state_and_data
  end

  def service_down({:call, from}, :notify_service_up, data) do
    actions = [{:reply, from, :ok}]
    {:next_state, :service_up, data, actions}
  end

  def service_down({:call, from}, {:notify_service_down, _reason}, _data) do
    actions = [{:reply, from, :already_notified}]
    {:keep_state_and_data, actions}
  end

  def service_up({:call, from}, :notify_service_up, _data) do
    actions = [{:reply, from, :ok}]
    {:keep_state_and_data, actions}
  end

  def service_up({:call, from}, {:notify_service_down, reason}, data) do
    reason
    |> Email.service_down_email()
    |> deliver()

    actions = [{:reply, from, :mail_sent}]
    {:next_state, :service_down, data, actions}
  end
end
