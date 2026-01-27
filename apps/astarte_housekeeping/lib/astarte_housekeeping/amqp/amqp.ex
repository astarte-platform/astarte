defmodule Astarte.Housekeeping.AMQP do
  @moduledoc """
  Http client for RabbitMQ Management API.

  This module extends `HTTPoison.Base` to provide automated base URL construction,
  Basic Authentication, and SSL configuration for all outgoing requests to the 
  RabbitMQ cluster Management endpoint.
  """
  use HTTPoison.Base

  alias Astarte.Housekeeping.Config

  @impl true
  def process_request_url(url) do
    Config.amqp_base_url!() <> url
  end

  @impl true
  def process_request_options(options) do
    auth_opts = [
      hackney: [basic_auth: {Config.amqp_username!(), Config.amqp_password!()}],
      ssl: Config.ssl_options!()
    ]

    Keyword.merge(auth_opts, options)
  end
end
