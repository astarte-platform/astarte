defmodule Astarte.Housekeeping.AMQP.Vhost do
  require Logger
  alias Astarte.Housekeeping.AMQP

  @spec create_vhost(String.t()) :: :ok | :error
  def create_vhost(realm) do
    vhost_name = vhost_name(realm)

    case AMQP.put("/api/vhosts/#{vhost_name}", "") do
      {:ok, %HTTPoison.Response{status_code: 201}} ->
        :ok

      {:ok, %HTTPoison.Response{status_code: 204}} ->
        "requested vhost already exists: skipping creation"
        |> Logger.warning(realm: realm)

        :ok

      {:ok, response} ->
        "error during vhost creation: unexpected response #{inspect(response)}"
        |> Logger.error(realm: realm)

        :error

      {:error, reason} ->
        "error during vhost creation: http error #{inspect(reason)}"
        |> Logger.error(realm: realm)

        :error
    end
  end

  def vhost_name(realm_name) do
    astarte_instance = Astarte.DataAccess.Config.astarte_instance_id!()
    "#{astarte_instance}_#{realm_name}"
  end
end
