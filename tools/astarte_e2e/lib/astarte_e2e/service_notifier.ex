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
  alias AstarteE2E.Config

  @default_failure_id "unknown"

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
    service_notifier_config = Config.service_notifier_config()

    configured_email =
      email
      |> Bamboo.ConfigAdapter.Email.put_config(service_notifier_config)

    with %Bamboo.Email{} = sent_email <- Mailer.deliver_later(configured_email) do
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
    data = %{
      failures_before_alert: Config.failures_before_alert!(),
      failure_id: @default_failure_id
    }

    {:ok, :starting, data, [{:state_timeout, 60_000, nil}]}
  end

  def starting(:state_timeout, _content, data) do
    reason = "Timeout at startup"

    event_id = Hukai.generate("%a-%A")

    # setting failures_before_alert to -1 prevent the system from sending two identical
    # email alerts
    updated_data =
      data
      |> Map.put(:failures_before_alert, -1)
      |> Map.put(:failure_id, event_id)

    reason
    |> Email.service_down_email(event_id)
    |> deliver()

    Logger.warn(
      "Service down. The user has been notified. Reason: #{reason}. FailureID: #{event_id}",
      tag: "service_down_notified"
    )

    {:next_state, :service_down, updated_data}
  end

  def starting({:call, from}, :notify_service_up, data) do
    actions = [{:reply, from, :ok}]

    updated_data = Map.put(data, :failures_before_alert, Config.failures_before_alert!())

    Logger.info("Service up.", tag: "service_up")
    {:next_state, :service_up, updated_data, actions}
  end

  def starting({:call, from}, {:notify_service_down, _reason}, _data) do
    actions = [{:reply, from, :not_started_yet}]
    {:keep_state_and_data, actions}
  end

  def service_down({:call, from}, :notify_service_up, %{failure_id: failure_id} = data) do
    actions = [{:reply, from, :ok}]

    updated_data =
      data
      |> Map.put(:failures_before_alert, Config.failures_before_alert!())
      |> Map.put(:failure_id, @default_failure_id)

    Email.service_up_email(failure_id)
    |> deliver()

    Logger.info("Service up. The user has been notified. Last FailureID: #{failure_id}.",
      tag: "service_up_notified"
    )

    {:next_state, :service_up, updated_data, actions}
  end

  def service_down(
        {:call, from},
        {:notify_service_down, reason},
        %{failures_before_alert: 0} = data
      ) do
    event_id = Hukai.generate("%a-%A")

    updated_data =
      data
      |> Map.put(:failures_before_alert, data.failures_before_alert - 1)
      |> Map.put(:failure_id, event_id)

    reason
    |> Email.service_down_email(event_id)
    |> deliver()

    Logger.warn(
      "Service down. The user has been notified. Reason: #{reason}. FailureID: #{event_id}",
      tag: "service_down_notified"
    )

    actions = [{:reply, from, :mail_sent}]

    {:keep_state, updated_data, actions}
  end

  def service_down(
        {:call, from},
        {:notify_service_down, _reason},
        data
      ) do
    actions =
      if data.failures_before_alert > 0 do
        [{:reply, from, :nothing_to_do}]
      else
        [{:reply, from, :mail_sent}]
      end

    updated_data = Map.put(data, :failures_before_alert, data.failures_before_alert - 1)

    {:keep_state, updated_data, actions}
  end

  def service_up({:call, from}, :notify_service_up, data) do
    actions = [{:reply, from, :ok}]

    updated_data = Map.put(data, :failures_before_alert, Config.failures_before_alert!())

    {:keep_state, updated_data, actions}
  end

  def service_up({:call, from}, {:notify_service_down, _reason}, data) do
    actions = [{:reply, from, :nothing_to_do}]

    updated_data = Map.put(data, :failures_before_alert, data.failures_before_alert - 1)

    {:next_state, :service_down, updated_data, actions}
  end
end
