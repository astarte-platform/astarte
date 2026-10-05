defmodule Astarte.Config.Binding.RequestOpts do
  @moduledoc """
  Skogsra binding that builds the request options (SSL and, when username and
  password are set, HTTP basic auth) from the service components.
  """
  use Skogsra.Binding

  alias Astarte.Config.Binding

  @impl true
  def init(_env), do: {:ok, nil}

  @impl true
  def get_env(env, _config) do
    with {:ok, ssl_opts} <- ssl_opts(env) do
      base_opts = [ssl: ssl_opts]
      {:ok, add_basic_auth(base_opts, env)}
    end
  end

  defp ssl_opts(env) do
    case Binding.fetch(env, :ssl_enabled) do
      {:ok, true} ->
        with {:ok, ca_file} <- Binding.fetch(env, :ssl_ca_file),
             {:ok, disable_sni} <- Binding.fetch(env, :ssl_disable_sni),
             {:ok, custom_sni} <- Binding.fetch(env, :ssl_custom_sni),
             {:ok, host} <- url_host(env) do
          {:ok, build_ssl_options(ca_file, disable_sni, custom_sni, host)}
        end

      _ ->
        {:ok, []}
    end
  end

  defp build_ssl_options(ca_file, disable_sni, custom_sni, host) do
    ssl_options = [cacertfile: ca_file, verify: :verify_peer, depth: 10]

    if disable_sni do
      Keyword.put(ssl_options, :server_name_indication, :disable)
    else
      server_name = custom_sni || host
      Keyword.put(ssl_options, :server_name_indication, to_charlist(server_name))
    end
  end

  defp url_host(env) do
    with {:ok, url} <- Binding.fetch(env, :url) do
      host = url |> URI.parse() |> Map.fetch!(:host)
      {:ok, host}
    end
  end

  defp add_basic_auth(base_opts, env) do
    with {:ok, username} when is_binary(username) <- Binding.fetch(env, :username),
         {:ok, password} when is_binary(password) <- Binding.fetch(env, :password) do
      Keyword.put(base_opts, :hackney, basic_auth: {username, password})
    else
      _ -> base_opts
    end
  end
end
