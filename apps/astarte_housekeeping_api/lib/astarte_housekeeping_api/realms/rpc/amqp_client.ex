defmodule Astarte.Housekeeping.API.Realms.RPC.AMQPClient do
  use Astarte.RPC.AMQPClient,
    rpc_queue: Application.fetch_env!(:astarte_housekeeping_api, :rpc_queue),
    amqp_options: Application.get_env(:astarte_housekeeping_api, :amqp_connection, [])

  use Astarte.RPC.Protocol.Housekeeping
  alias Astarte.Housekeeping.API.Realms.Realm

  def create_realm(realm = %Realm{realm_name: realm_name}) do
    %CreateRealm{realm: realm_name}
    |> encode_call(:create_realm)
    |> rpc_call()

    {:ok, realm}
  end

  defp encode_call(call = %CreateRealm{}, :create_realm) do
    %Call{call: {:create_realm, call}}
    |> Call.encode()
  end
end
