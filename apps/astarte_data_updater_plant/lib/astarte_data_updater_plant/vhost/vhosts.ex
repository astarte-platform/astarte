defmodule Astarte.DataUpdaterPlant.Vhosts do
  alias Astarte.DataUpdaterPlant.Config

  def create_vhost(realm) do
    realm = vhost_name(realm)

    rabbit_client()
    |> ExRabbitMQAdmin.Vhost.put_vhost(realm)
  end

  def delete_vhost(realm) do
    realm = vhost_name(realm)

    rabbit_client()
    |> ExRabbitMQAdmin.Vhost.delete_vhost(realm)

    :ok
  end

  defp rabbit_client() do
    ExRabbitMQAdmin.client(base_url: Config.amqp_base_url!())
    |> ExRabbitMQAdmin.add_basic_auth_middleware(
      username: Config.amqp_username!(),
      password: Config.amqp_password!()
    )
  end

  def vhost_name(realm_name) do
    astarte_instance = Astarte.DataAccess.Config.astarte_instance_id!()
    "astarte_triggers_#{astarte_instance}_#{realm_name}"
  end
end
