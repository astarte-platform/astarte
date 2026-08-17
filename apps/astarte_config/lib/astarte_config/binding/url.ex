defmodule Astarte.Config.Binding.URL do
  @moduledoc """
  Skogsra binding that composes the service URL from its base components when
  the whole URL is not set.
  """
  use Skogsra.Binding

  alias Astarte.Config.Binding

  @impl true
  def init(_env), do: {:ok, nil}

  @impl true
  def get_env(env, _config) do
    with {:ok, scheme} <- Binding.fetch(env, :scheme),
         {:ok, host} <- Binding.fetch(env, :host),
         {:ok, port} <- Binding.fetch(env, :port),
         {:ok, path} <- Binding.fetch(env, :path),
         {:ok, query} <- Binding.fetch(env, :query),
         {:ok, fragment} <- Binding.fetch(env, :fragment) do
      url =
        %URI{
          scheme: scheme,
          host: host,
          port: port,
          path: path,
          query: query,
          fragment: fragment
        }
        |> URI.to_string()

      {:ok, url}
    end
  end
end
