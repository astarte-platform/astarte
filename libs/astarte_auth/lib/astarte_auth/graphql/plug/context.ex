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
  Plug that extracts authentication information from the request, verifies
  JWTs through the service's own Guardian implementation, and builds the
  Absinthe context that `Astarte.Auth.GraphQL.Middleware.AuthorizeFGA` and
  the service's resolvers read.

  ```elixir
  pipeline :graphql do
    plug Astarte.Auth.GraphQL.Plug.Context,
      otp_app: :astarte_pairing,
      guardian: Astarte.PairingWeb.AuthGuardian,
      verify_header: Astarte.PairingWeb.Plug.VerifyHeader,
      config: Astarte.Pairing.Config
  end
  ```

  Options, all required, since each is service-specific:

  - `otp_app` — the service's OTP application, used to read its Guardian config.
  - `guardian` — the service's `Guardian` implementation.
  - `verify_header` — the service's `Guardian.Plug.VerifyHeader` wrapper, which
    resolves the realm's JWT public key from the connection.
  - `config` — the service's `Config` module, read for `authentication_disabled?/0`.

  The context it puts together holds:

  - `:realm_name` — the realm from the `astarte-realm` request header.
  - `:current_user` — the resource Guardian loaded, or `nil`.
  - `:auth_token` — the raw bearer token, for endpoints authenticated by a
    device's credentials secret rather than by a JWT.
  - `:remote_ip` — the caller's IP address.
  - `:authentication_disabled?` — whether the service has authentication off.

  This plug never halts the connection, leaving error formatting to the
  Absinthe resolvers.
  """

  @behaviour Plug

  import Plug.Conn

  alias Guardian.Plug.LoadResource
  alias Guardian.Plug.Pipeline

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
  def init(opts) do
    %{
      otp_app: Keyword.fetch!(opts, :otp_app),
      guardian: Keyword.fetch!(opts, :guardian),
      verify_header: Keyword.fetch!(opts, :verify_header),
      config: Keyword.fetch!(opts, :config)
    }
  end

  @impl Plug
  def call(conn, opts) do
    auth_token = conn |> get_req_header("authorization") |> find_bearer_token()
    realm_name = conn |> get_req_header("astarte-realm") |> List.first()
    remote_ip = conn.remote_ip |> :inet_parse.ntoa() |> to_string()

    {conn, current_user} = verify_jwt(conn, realm_name, opts)

    context = %{
      realm_name: realm_name,
      current_user: current_user,
      auth_token: auth_token,
      remote_ip: remote_ip,
      authentication_disabled?: opts.config.authentication_disabled?()
    }

    Absinthe.Plug.put_options(conn, context: context)
  end

  defp verify_jwt(conn, realm_name, opts) do
    %{otp_app: otp_app, guardian: guardian, verify_header: verify_header} = opts

    # The VerifyHeader wrapper recovers the realm's JWT public key from the
    # connection, and reads the realm from the assigns since this plug doesn't
    # go through regular Phoenix routing.
    conn = if realm_name, do: assign(conn, :realm_name, realm_name), else: conn

    pipeline_opts =
      Pipeline.init(
        otp_app: otp_app,
        module: guardian,
        error_handler: __MODULE__.ErrorHandler
      )

    # VerifyHeader.init/1 compiles the :scheme_reg regex that Guardian uses to
    # strip the "Bearer " prefix from the Authorization header. Without it, the
    # entire header value (including "Bearer ") is passed to decode_and_verify,
    # which fails.
    verify_header_opts = verify_header.init([])
    load_resource_opts = LoadResource.init(allow_blank: true)

    conn =
      conn
      |> Pipeline.call(pipeline_opts)
      |> verify_header.call(verify_header_opts)
      |> LoadResource.call(load_resource_opts)

    # Includes the authorizations carried by the service's claims.
    current_user = Guardian.Plug.current_resource(conn)

    # Guardian halts on an invalid or missing token; un-halt so the resolvers
    # can report their own errors.
    {%{conn | halted: false}, current_user}
  end

  defp find_bearer_token([]), do: nil

  defp find_bearer_token([auth_header | tail]) do
    case Regex.run(@bearer_regex, auth_header) do
      [_, match] -> match
      _ -> find_bearer_token(tail)
    end
  end
end
