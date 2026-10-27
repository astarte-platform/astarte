defmodule Astarte.Config do
  @moduledoc """
  App configuration based on Skogsra.

  Provides the `url_env/4` macro to declare the configuration of a service,
  generating skogsra environment variables for its components and derived
  values (base URL, SSL options, request options) that can be plugged into
  `Astarte.Config.HTTPClient`.

  ```elixir
  defmodule MyApp.Config do
    use Astarte.Config, env_app: "ASTARTE"

    url_env :my_service, :my_app, :my_service
  end
  ```
  """

  defmacro __using__(opts) do
    env_app = Keyword.get(opts, :env_app)

    quote do
      use Skogsra

      import Astarte.Config

      @astarte_config_env_app unquote(env_app)
    end
  end

  @doc """
  Declares the configuration of `service`, which lives in the `app` application
  under the given `keys`.

  The whole URL can be configured through the `URL` OS environment variable;
  otherwise it is composed from the scheme/host/port/path/query/fragment
  components.

  Available options:

  | Option             | Type      | Default          | Description                                        |
  | ------------------ | --------- | ---------------- | -------------------------------------------------- |
  | `scheme`           | `binary`  | `"http"`         | Scheme used when SSL is disabled.                  |
  | `scheme_ssl`       | `binary`  | `\#{scheme}s`    | Scheme used when SSL is enabled.                   |
  | `default_port`     | `integer` | -                | Default port                                       |
  | `default_user`     | `binary`  | —                | Default username for HTTP basic auth.              |
  | `default_password` | `binary`  | —                | Default password for HTTP basic auth.              |
  | `env_app`          | `binary`  | module `env_app` | Prefix for the generated OS environment variables. |

  The `username` and `password` components are always declared; the request
  options include HTTP basic auth only when both are set.
  """
  defmacro url_env(service, app, keys, opts \\ []) do
    env_app = env_app(__CALLER__.module, app, opts)

    components = components(env_app, service, opts)

    url_opts = [
      os_env: os_env(env_app, service, :url),
      type: :binary,
      default: nil,
      binding_order: [:system, :config, Astarte.Config.Binding.URL],
      components: components
    ]

    request_opts_opts = [
      type: :any,
      default: nil,
      binding_order: [Astarte.Config.Binding.RequestOpts],
      components: Keyword.put(components, :url, url_opts)
    ]

    quote do
      unquote_splicing(Enum.map(components, &app_env_quoted(service, app, keys, &1)))

      app_env unquote(function_name(service, :url)),
              unquote(app),
              unquote(keys(keys, :url)),
              unquote(url_opts)

      app_env unquote(function_name(service, :request_opts)),
              unquote(app),
              unquote(keys(keys, :request_opts)),
              unquote(request_opts_opts)
    end
  end

  defp default_components(opts) do
    port_default_opts = [type: :pos_integer]

    port_opts =
      case Keyword.fetch(opts, :default_port) do
        {:ok, port} -> Keyword.put(port_default_opts, :default, port)
        :error -> port_default_opts
      end

    [
      userinfo: [type: :binary, default: ""],
      host: [type: :binary, default: "localhost"],
      port: port_opts,
      path: [type: :binary],
      query: [type: :binary],
      fragment: [type: :binary]
    ]
  end

  defp ssl_components do
    [
      ssl_enabled: [type: :boolean, default: false],
      ssl_ca_file: [type: :binary, default: CAStore.file_path()],
      ssl_disable_sni: [type: :boolean, default: false],
      ssl_custom_sni: [type: :binary]
    ]
  end

  # Each component gets its OS env var name. The scheme env additionally carries
  # the specs of the two components its binding reads, instead of the whole list:
  # the stored list is embedded in the env options, so it must not include the
  # scheme entry itself or it would be recursive.
  defp components(env_app, service, opts) do
    components =
      for {component, component_opts} <- base_components(opts) do
        {component, Keyword.put(component_opts, :os_env, os_env(env_app, service, component))}
      end

    Keyword.update!(components, :scheme, fn scheme_opts ->
      siblings = Keyword.take(components, [:scheme_ssl, :ssl_enabled])
      Keyword.put(scheme_opts, :components, siblings)
    end)
  end

  defp app_env_quoted(service, app, keys, {component, component_opts}) do
    function_name = function_name(service, component)

    quote do
      app_env unquote(function_name),
              unquote(app),
              unquote(keys(keys, component)),
              unquote(component_opts)
    end
  end

  defp base_components(opts) do
    scheme_default = base_scheme(opts)

    scheme = [
      scheme: [
        type: :binary,
        default: scheme_default,
        binding_order: [Astarte.Config.Binding.Scheme, :system, :config]
      ],
      scheme_ssl: [type: :binary, default: ssl_scheme(opts, scheme_default)]
    ]

    auth = [
      username: [type: :binary, default: opts[:default_user]],
      password: [type: :binary, default: opts[:default_password]]
    ]

    scheme ++ default_components(opts) ++ ssl_components() ++ auth
  end

  defp env_app(module, app, opts) do
    opts[:env_app] || Module.get_attribute(module, :astarte_config_env_app) ||
      app |> Atom.to_string() |> String.upcase()
  end

  defp base_scheme(opts) do
    Keyword.get(opts, :scheme, "http")
  end

  defp ssl_scheme(opts, scheme) do
    Keyword.get(opts, :scheme_ssl, scheme <> "s")
  end

  defp function_name(service, component) do
    service = service |> Atom.to_string()
    component = component |> Atom.to_string()
    name = "#{service}_#{component}"
    String.to_atom(name)
  end

  defp keys(keys, component) do
    List.wrap(keys) ++ [component]
  end

  defp os_env(env_app, service, component) do
    suffix = component |> Atom.to_string() |> String.upcase()
    service_str = service |> Atom.to_string() |> String.upcase()

    "#{env_app}_#{service_str}_#{suffix}"
  end
end
