defmodule Astarte.Pairing.APIWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use Astarte.Pairing.APIWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(Astarte.Pairing.APIWeb.ChangesetView, "error.json", changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> render(Astarte.Pairing.APIWeb.ErrorView, :"404")
  end

  def call(conn, {:error, _reason}) do
    conn
    |> put_status(:internal_server_error)
    |> render(Astarte.Pairing.APIWeb.ErrorView, :"500")
  end

  # This is the final call made by EnsureAuthenticated
  def auth_error(conn, {:unauthenticated, _reason}, _opts) do
    conn
    |> put_status(:unauthorized)
    |> render(Astarte.Pairing.APIWeb.ErrorView, :"401")
  end
  # We don't care about intermediate errors
  def auth_error(conn, _reason, _opts), do: conn
end
