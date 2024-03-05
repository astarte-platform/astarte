defmodule Astarte.AppEngine.APIWeb.Plug.GroupNameDecoder do
  @moduledoc """
  This plug decodes a group name, which may have been coded
  to remove the forward slash
  """
  def init(default), do: default

  def call(%Plug.Conn{path_params: %{"group_name" => group_name}} = conn, _) do
    %Plug.Conn{conn | path_params: %{conn.path_params | "group_name" => URI.decode(group_name)}}
  end

  def call(conn, _), do: conn
end
