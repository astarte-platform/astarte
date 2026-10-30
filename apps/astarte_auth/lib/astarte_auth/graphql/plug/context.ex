#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.Auth.GraphQL.Plug.Context do
  @moduledoc """
  Builds the Absinthe context read by `Astarte.Auth.GraphQL.Middleware.AuthorizeFGA`
  and the resolvers. The service's Guardian plugs must run before it, without
  halting:

  ```elixir
  pipeline :graphql do
    plug Guardian.Plug.Pipeline,
      otp_app: :astarte_pairing,
      module: Astarte.PairingWeb.AuthGuardian,
      error_handler: Context.ErrorHandler

    plug Astarte.PairingWeb.Plug.VerifyHeader, halt: false
    plug Guardian.Plug.LoadResource, allow_blank: true, halt: false
    plug Context
  end
  ```

  The context it puts together holds:

  - `:realm_name` - the realm from the `astarte-realm` request header.
  - `:current_user` - the resource Guardian loaded, or `nil`.
  - `:auth_token` - the raw bearer token, for endpoints authenticated by a
    device's credentials secret rather than by a JWT.
  - `:remote_ip` - the caller's IP address.
  """

  @behaviour Plug

  import Plug.Conn

  @bearer_regex ~r/bearer\:?\s+(.*)$/i

  defmodule ErrorHandler do
    @moduledoc """
    No-op Guardian error handler: authentication failures never halt the
    connection, since error formatting is left to the Absinthe resolvers.
    """

    @behaviour Guardian.Plug.ErrorHandler

    @impl Guardian.Plug.ErrorHandler
    def auth_error(conn, _error, _opts), do: conn
  end

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    context = %{
      realm_name: conn |> get_req_header("astarte-realm") |> List.first(),
      current_user: Guardian.Plug.current_resource(conn),
      auth_token: conn |> get_req_header("authorization") |> find_bearer_token(),
      remote_ip: conn.remote_ip |> :inet_parse.ntoa() |> to_string()
    }

    Absinthe.Plug.put_options(conn, context: context)
  end

  defp find_bearer_token(auth_headers) do
    Enum.find_value(auth_headers, fn auth_header ->
      case Regex.run(@bearer_regex, auth_header) do
        [_, token] -> token
        _ -> nil
      end
    end)
  end
end
