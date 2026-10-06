defmodule Astarte.VMQ.Plugin.HealthHttp.Handler do
  @moduledoc """
  Custom Cowboy handler to add an /healthz endpoint reporting status of
  EventsProducer workers and their AMQP connection toward RabbitMQ instance
  """

  alias Mississippi.Producer.Healthcheck

  def routes do
    [
      {"/healthz", __MODULE__, []}
    ]
  end

  def init(req, state) do
    {status_code, body} =
      case Healthcheck.check_all() do
        :ok ->
          {200, %{status: "OK"}}

        {:error, errors} when is_list(errors) ->
          {503, %{status: "DOWN", reasons: errors}}
      end

    json_body = Jason.encode!(body)

    reply =
      :cowboy_req.reply(
        status_code,
        %{"content-type" => "application/json"},
        json_body,
        req
      )

    {:ok, reply, state}
  end
end
