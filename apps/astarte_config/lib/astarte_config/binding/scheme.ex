defmodule Astarte.Config.Binding.Scheme do
  @moduledoc """
  Skogsra binding that makes the `scheme` variable SSL-aware: when
  `ssl_enabled` is set, the scheme is the one of `scheme_ssl`.
  """
  use Skogsra.Binding

  alias Astarte.Config.Binding

  @impl true
  def init(_env), do: {:ok, nil}

  @impl true
  def get_env(env, _config) do
    case Binding.fetch(env, :ssl_enabled) do
      {:ok, true} -> Binding.fetch(env, :scheme_ssl)
      _ -> {:ok, nil}
    end
  end
end
