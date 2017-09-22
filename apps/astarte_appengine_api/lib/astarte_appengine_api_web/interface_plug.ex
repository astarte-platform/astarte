defmodule AstarteAppengineApiWeb.InterfacePlug do

  def init(options) do
    options
  end

  @doc """
  Rewrites any request to "/v1/:realm_name/devices/:device_id/interfaces/:interface/PATH" to "/v1/:realm_name/devices/:device_id/interfaces/:interface".
  Everything will be handled by phoenix router later.
  """
  def call(conn, _opts) do
      if match?(["v1", _, "devices", _, "interfaces", _ | _], conn.path_info) do
        ["v1", realm_name, "devices", device_id, "interfaces", interface | subpath] = conn.path_info
        old_query_string = conn.query_string

        %{ conn |
          path_info: ["v1", realm_name, "devices", device_id, "interfaces", interface],
          request_path: "/v1/#{realm_name}/devices/#{device_id}/interfaces/#{interface}",
          query_params: %{"path" => Enum.join(subpath, "/")},
          query_string: "path=#{Enum.join(subpath, "%2F")}&#{old_query_string}"
        }
      else
        conn
      end
  end
end
