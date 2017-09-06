defmodule Astarte.Housekeeping.APIWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use Astarte.Housekeeping.APIWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(Astarte.Housekeeping.APIWeb.ChangesetView, "error.json", changeset: changeset)
  end

  def call(conn, {:error, :realm_not_found}) do
    conn
    |> put_status(:not_found)
    |> render(Astarte.Housekeeping.APIWeb.ErrorView, :realm_not_found)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> render(Astarte.Housekeeping.APIWeb.ErrorView, :"404")
  end
end
