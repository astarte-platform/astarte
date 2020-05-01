defmodule Astarte.RealmManagement.API.Triggers.Action do
  alias Astarte.RealmManagement.API.Triggers.{AMQPAction, HttpAction}

  @behaviour Ecto.Type

  @impl true
  def type, do: :map

  @impl true
  def cast(action = %{"amqp_exchange" => _}) do
    EctoMorph.cast_to_struct(action, AMQPAction)
  end

  def cast(action = %{amqp_exchange: _}) do
    EctoMorph.cast_to_struct(action, AMQPAction)
  end

  def cast(action = %{"http_url" => _}) do
    EctoMorph.cast_to_struct(action, HttpAction)
  end

  def cast(action = %{http_url: _}) do
    EctoMorph.cast_to_struct(action, HttpAction)
  end

  def cast(action = %{"http_post_url" => _}) do
    EctoMorph.cast_to_struct(action, HttpAction)
  end

  def cast(action = %{http_post_url: _}) do
    EctoMorph.cast_to_struct(action, HttpAction)
  end

  @impl true
  def embed_as(_), do: :self

  @impl true
  def equal?(left, right), do: left == right
end
