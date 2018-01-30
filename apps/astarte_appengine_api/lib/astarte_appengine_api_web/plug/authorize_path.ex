defmodule Astarte.AppEngine.APIWeb.Plug.AuthorizePath do
  use Plug.Builder

  import Plug.Conn

  require Logger

  alias Astarte.AppEngine.API.Auth.User
  alias Astarte.AppEngine.APIWeb.AuthGuardian
  alias Astarte.AppEngine.APIWeb.FallbackController

  plug Guardian.Plug.Pipeline,
    otp_app: :astarte_appengine_api,
    module: Astarte.AppEngine.APIWeb.AuthGuardian,
    error_handler: FallbackController
  plug Astarte.AppEngine.APIWeb.Plug.VerifyHeader
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
  plug :authorize

  defp authorize(conn, opts) do
    with %User{authorizations: authorizations} <- AuthGuardian.Plug.current_resource(conn),
         {:ok, auth_path} <- build_auth_path(conn),
         :ok <- is_path_authorized?(conn.method, auth_path, authorizations) do
      conn
    else
      {:error, :invalid_auth_path} ->
        Logger.warn("Can't build auth_path with path_params: #{inspect conn.path_params} path_info: #{inspect conn.path_info} query_params: #{inspect conn.query_params}")
        conn
        |> FallbackController.auth_error({:unauthorized, :invalid_auth_path}, opts)
        |> halt()

      {:error, {:unauthorized, method, auth_path, authorizations}} ->
        Logger.info("Unauthorized request: #{method} #{auth_path} failed with authorizations #{inspect authorizations}")
        conn
        |> FallbackController.auth_error({:unauthorized, :authorization_path_not_matched}, opts)
        |> halt()
    end
  end

  defp build_auth_path(conn) do
    with %{"realm_name" => realm} <- conn.path_params,
         [^realm | rest] <- Enum.drop_while(conn.path_info, fn token -> token != realm end),

      path_prefix = Enum.join(rest, "/") do
      path_suffix =
        if Map.has_key?(conn.query_params, "path") do
          "/#{Map.get(conn.query_params, "path")}"
        else
          ""
        end

      {:ok, "#{path_prefix}#{path_suffix}"}
    else
      _ ->
        {:error, :invalid_auth_path}
    end
  end

  defp is_path_authorized?(method, auth_path, authorizations) when is_list(authorizations) do
    authorized =
      Enum.any?(authorizations, fn auth_string ->
        case get_auth_regex(auth_string) do
          {:ok, {method_regex, path_regex}} ->
            Regex.match?(method_regex, method) and Regex.match?(path_regex, auth_path)
          _ ->
            false
        end
      end)

    if authorized do
      :ok
    else
      {:error, {:unauthorized, method, auth_path, authorizations}}
    end
  end

  defp is_path_authorized?(method, auth_path, authorizations), do: {:error, {:unauthorized, method, auth_path, authorizations}}

  defp get_auth_regex(authorization_string) do
    # TODO: right now regex have to be terminated with $ manually, otherwise they also match prefix.
    # We can think about always terminating them here appending a $ to the string
    with [method_auth, _opts, path_auth] <- String.split(authorization_string, ":", parts: 3),
         {:ok, method_regex} <- Regex.compile(method_auth),
         {:ok, path_regex} <- Regex.compile(path_auth) do

      {:ok, {method_regex, path_regex}}
    else
      [] ->
        {:error, :invalid_authorization_string}
      _ ->
        {:error, :invalid_regex}
    end
  end
end
