defmodule Astarte.PairingWeb.Plug.GraphQLContext do
  @moduledoc """
  Plug that extracts authentication information from the request,
  verifies JWTs via Guardian, and builds the Absinthe context.

  This plug never halts the connection, leaving error formatting
  to the Absinthe resolvers.
  """
  @behaviour Plug

  import Plug.Conn

  alias Astarte.PairingWeb.AuthGuardian
  alias Astarte.PairingWeb.Plug.VerifyHeader
  alias Guardian.Plug.LoadResource
  alias Guardian.Plug.Pipeline

  @bearer_regex ~r/bearer\:?\s+(.*)$/i

  defmodule ErrorHandler do
    @moduledoc """
    No-op Guardian error handler: authentication failures never halt the
    connection, since error formatting is left to the Absinthe resolvers.
    """

    @behaviour Guardian.Plug.ErrorHandler
    def auth_error(conn, _error, _opts), do: conn
  end

  def init(opts), do: opts

  def call(conn, _) do
    raw_token = conn |> get_req_header("authorization") |> find_secret()
    realm = conn |> get_req_header("astarte-realm") |> List.first()
    device_ip = conn.remote_ip |> :inet_parse.ntoa() |> to_string()

    {conn, current_user} = verify_jwt(conn, realm)

    context = %{
      device_secret: raw_token,
      realm_name: realm,
      current_user: current_user,
      device_ip: device_ip
    }

    Absinthe.Plug.put_options(conn, context: context)
  end

  defp verify_jwt(conn, realm) do
    conn = if realm, do: assign(conn, :realm_name, realm), else: conn

    pipeline_opts =
      Pipeline.init(
        otp_app: :astarte_pairing,
        module: Astarte.PairingWeb.AuthGuardian,
        error_handler: __MODULE__.ErrorHandler
      )

    # VerifyHeader.init/1 compiles the :scheme_reg regex that Guardian
    # uses to strip the "Bearer " prefix from the Authorization header.
    # Without it, the entire header value (including "Bearer ") is passed
    # to decode_and_verify, which fails.
    verify_header_opts = VerifyHeader.init([])
    load_resource_opts = LoadResource.init(allow_blank: true)

    c = Pipeline.call(conn, pipeline_opts)
    c = VerifyHeader.call(c, verify_header_opts)
    c = LoadResource.call(c, load_resource_opts)

    # Extract the authenticated user (includes authorizations from a_pa claims)
    user = AuthGuardian.Plug.current_resource(c)

    # Guardian halts on an invalid/missing token; un-halt so resolvers can
    # report their own errors.
    {%{c | halted: false}, user}
  end

  defp find_secret([]), do: nil

  defp find_secret([auth_header | tail]) do
    case Regex.run(@bearer_regex, auth_header) do
      [_, match] -> match
      _ -> find_secret(tail)
    end
  end
end
