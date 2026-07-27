defmodule SampleConfig do
  @moduledoc false

  use Astarte.Config, env_app: "ASTARTE_CONFIG"

  url_env :my_service, :astarte_config, :my_service, env_app: "ASTARTE"

  url_env :ftp_service, :astarte_config, :ftp_service, scheme: "ftp", default_port: 8080

  url_env :custom_ssl_scheme, :astarte_config, :custom_ssl_scheme,
    scheme: "myscheme",
    scheme_ssl: "myschemessl"

  url_env :amqp_management_service, :astarte_config, :amqp_management_service,
    default_user: "guest",
    default_password: "guest"
end
