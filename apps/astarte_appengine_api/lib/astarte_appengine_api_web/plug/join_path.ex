defmodule Astarte.AppEngine.APIWeb.Plug.JoinPath do
  @moduledoc """
  This plug looks for `path_tokens` in `path_params`. If it finds it, it joins
  the tokens and inserts the `path` param in `params` and `path_params`.
  """

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    with {:ok, tokens} when is_list(tokens) <- Map.fetch(conn.path_params, "path_tokens") do
      path = Enum.join(tokens, "/")
      new_path_params = Map.put(conn.path_params, "path", path)
      new_params = Map.put(conn.params, "path", path)

      %{conn | path_params: new_path_params, params: new_params}
    else
      _ ->
        conn
    end
  end
end
