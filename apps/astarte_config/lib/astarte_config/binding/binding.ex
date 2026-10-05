defmodule Astarte.Config.Binding do
  @moduledoc false

  alias Skogsra.Core
  alias Skogsra.Env

  @spec fetch(Env.t(), atom()) :: {:ok, term()} | {:error, binary()}
  def fetch(env, component) do
    base_keys = List.delete_at(env.keys, -1)

    case Keyword.fetch(env.options[:components] || [], component) do
      {:ok, component_opts} ->
        Core.get_env(
          Env.new(env.namespace, env.app_name, base_keys ++ [component], component_opts)
        )

      :error ->
        {:error, "Cannot fetch component #{inspect(component)} for env #{inspect(env)}"}
    end
  end
end
