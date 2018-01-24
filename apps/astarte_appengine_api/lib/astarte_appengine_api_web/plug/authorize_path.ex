defmodule Astarte.AppEngine.APIWeb.Plug.AuthorizePath do
  use Plug.Builder

  import Plug.Conn

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
         true <- is_path_authorized?(conn.method, auth_path, authorizations) do
      conn
    else
      _ ->
        conn
        |> FallbackController.auth_error({:unauthorized, :authorized_path_not_matched}, opts)
        |> halt()
    end
  end

  defp build_auth_path(conn) do
    %{"realm_name" => realm} = conn.path_params

    case Enum.drop_while(conn.path_info, fn token -> token != realm end) do
      [^realm | rest] ->
        {:ok, Enum.join(rest, "/")}

      _ ->
        {:error, :invalid_auth_path}
    end
  end

  defp is_path_authorized?(method, auth_path, authorizations) do
    Enum.any?(authorizations, fn auth_string ->
      case get_auth_regex(auth_string) do
        {:ok, {method_regex, path_regex}} ->
          Regex.match?(method_regex, method) and Regex.match?(path_regex, auth_path)
        _ ->
          false
      end
    end)
  end

  defp get_auth_regex(authorization_string) do
    [method_auth, _opts, path_auth] = String.split(authorization_string, ":", parts: 3)

    # TODO: right now regex have to be terminated with $ manually, otherwise they also match prefix.
    # We can think about always terminating them here appending a $ to the string
    with {:ok, method_regex} <- Regex.compile(method_auth),
         {:ok, path_regex} <- Regex.compile(path_auth) do

      {:ok, {method_regex, path_regex}}
    end
  end
end
