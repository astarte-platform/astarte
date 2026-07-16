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

  require Logger

  @bearer_regex ~r/bearer\:?\s+(.*)$/i

  # A minimal structural check for JWTs: three non-empty dot-separated segments
  # using base64url characters (header.payload.signature).  Credentials
  # secrets are short random strings without embedded dots, so this regex
  # reliably distinguishes them from JWTs without trying to decode the token.
  @jwt_pattern ~r/^[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+$/

  defmodule ErrorHandler do
    @behaviour Guardian.Plug.ErrorHandler
    def auth_error(conn, _error, _opts), do: conn
  end

  def init(opts), do: opts

  def call(conn, _) do
    raw_token = conn |> get_req_header("authorization") |> find_secret()
    realm = conn |> get_req_header("astarte-realm") |> List.first()

    # Determine whether the token looks like a JWT (header.payload.signature)
    # or a raw device credentials secret.  We use a proper structural regex
    # rather than just counting dots so that a credentials secret that happens
    # to contain exactly two dots cannot be mistaken for a JWT.
    is_jwt = is_binary(raw_token) and Regex.match?(@jwt_pattern, raw_token)

    {conn, current_user} =
      if is_jwt do
        # Inject realm_name into path_params so VerifyHeader can look up
        # the realm's public key (it reads conn.path_params["realm_name"])
        conn_with_realm =
          if realm do
            %{
              conn
              | path_params: Map.put(conn.path_params, "realm_name", realm),
                path_info: ["v1", realm, "devices"]
            }
          else
            conn
          end

        # Run the Guardian pipeline to verify the JWT
        pipeline_opts =
          Guardian.Plug.Pipeline.init(
            otp_app: :astarte_pairing,
            module: Astarte.PairingWeb.AuthGuardian,
            error_handler: __MODULE__.ErrorHandler
          )

        # VerifyHeader.init/1 compiles the :scheme_reg regex that Guardian
        # uses to strip the "Bearer " prefix from the Authorization header.
        # Without it, the entire header value (including "Bearer ") is passed
        # to decode_and_verify, which fails.
        verify_header_opts = Astarte.PairingWeb.Plug.VerifyHeader.init([])
        load_resource_opts = Guardian.Plug.LoadResource.init(allow_blank: true)

        c = Guardian.Plug.Pipeline.call(conn_with_realm, pipeline_opts)
        c = Astarte.PairingWeb.Plug.VerifyHeader.call(c, verify_header_opts)
        c = Guardian.Plug.LoadResource.call(c, load_resource_opts)

        # Extract the authenticated user (includes authorizations from a_pa claims)
        user = AuthGuardian.Plug.current_resource(c)

        # Unset halted flag so Absinthe can process the request
        {%{c | halted: false}, user}
      else
        {conn, nil}
      end

    context =
      %{}
      |> put_if_present(:device_secret, raw_token)
      |> put_if_present(:realm_name, realm)
      |> put_if_present(:current_user, current_user)

    Absinthe.Plug.put_options(conn, context: context)
  end

  defp find_secret([]), do: nil

  defp find_secret([auth_header | tail]) do
    case Regex.run(@bearer_regex, auth_header) do
      [_, match] -> match
      _ -> find_secret(tail)
    end
  end

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)
end
