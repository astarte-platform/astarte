defmodule Astarte.AppEngine.APIWeb.Plug.GuardianAuthorizePath do
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
        authorize_path_info = Map.get(conn.assigns, :original_path_info, conn.path_info)

        Logger.warn(
          "Can't build auth_path with path_params: #{inspect(conn.path_params)} path_info: #{
            inspect(authorize_path_info)
          } query_params: #{inspect(conn.query_params)}"
        )

        conn
        |> FallbackController.auth_error({:unauthorized, :invalid_auth_path}, opts)
        |> halt()

      {:error, {:unauthorized, method, auth_path, authorizations}} ->
        Logger.info(
          "Unauthorized request: #{method} #{auth_path} failed with authorizations #{
            inspect(authorizations)
          }"
        )

        conn
        |> FallbackController.auth_error({:unauthorized, :authorization_path_not_matched}, opts)
        |> halt()
    end
  end

  defp build_auth_path(conn) do
    with %{"realm_name" => realm} <- conn.path_params,
         authorize_path_info <- Map.get(conn.assigns, :original_path_info, conn.path_info),
         [^realm | rest] <- Enum.drop_while(authorize_path_info, fn token -> token != realm end),
         auth_path <- Enum.join(rest, "/") do
      {:ok, auth_path}
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

  defp is_path_authorized?(method, auth_path, authorizations),
    do: {:error, {:unauthorized, method, auth_path, authorizations}}

  # TODO: this should be fixed at InterfacePlug level
  defp rewrite_post_to_put_workaround("POST") do
    "PUT"
  end

  defp rewrite_post_to_put_workaround(any_method) do
    any_method
  end

  defp get_auth_regex(authorization_string) do
    with [method_auth, _opts, path_auth] <- String.split(authorization_string, ":", parts: 3),
         method_auth_no_post = rewrite_post_to_put_workaround(method_auth),
         {:ok, method_regex} <- build_regex(method_auth_no_post),
         {:ok, path_regex} <- build_regex(path_auth) do
      {:ok, {method_regex, path_regex}}
    else
      [] ->
        {:error, :invalid_authorization_string}

      _ ->
        {:error, :invalid_regex}
    end
  end

  defp build_regex(auth_string) do
    has_begin_delimiter = String.starts_with?(auth_string, "^")
    has_end_delimiter = String.ends_with?(auth_string, "$")

    delimited_auth_string =
      cond do
        has_begin_delimiter and has_end_delimiter ->
          auth_string

        has_begin_delimiter ->
          "#{auth_string}$"

        has_end_delimiter ->
          "^#{auth_string}"

        # No delimiters
        true ->
          "^#{auth_string}$"
      end

    Regex.compile(delimited_auth_string)
  end
end