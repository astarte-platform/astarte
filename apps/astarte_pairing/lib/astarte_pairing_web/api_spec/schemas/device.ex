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

defmodule Astarte.PairingWeb.ApiSpec.Schemas.Device do
  @moduledoc false
  alias OpenApiSpex.Schema

  defmodule InfoResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "InfoResponse",
      type: :object,
      properties: %{
        version: %Schema{type: :string},
        status: %Schema{type: :string},
        protocols: %Schema{type: :object}
      },
      example: %{
        version: "0.1.0",
        status: "confirmed",
        protocols: %{
          astarte_mqtt_v1: %{
            broker_url: "ssl://broker.astarte.example.com:8883"
          }
        }
      }
    })
  end

  defmodule AstarteMQTTV1CredentialsRequest do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AstarteMQTTV1CredentialsRequest",
      type: :object,
      properties: %{
        csr: %Schema{type: :string}
      },
      example: %{
        csr: """
        -----BEGIN CERTIFICATE REQUEST-----
        MIICnTCCAYUCAQAwWDELMAkGA1UEBhMCSVQxFDASBgNVBAgMC0V4YW1wbGVMYW5k
        MSEwHwYDVQQKDBhJbnRlcm5ldCBXaWRnaXRzIFB0eSBMdGQxEDAOBgNVBAMMB0V4
        YW1wbGUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC6B6eGPsTLsP09
        FzxFUKY95GaPnBU1niq1tx1vtA+r9BBnnoUn4JwNHtu5YTWMnlIJtfAs43ltLOrS
        Wyvcedg4e6Bh3nztqyD+4uSpzlSI54zexbztVAzzDvVlEuW0wMRgkqF7ez7OixGF
        BHdPgWKTxagVrYdqX/UjNm9f/Wnd3eCA9mEVwsARUlxRgLs0KPXPkqEGCxbcLSx3
        lJR28YE+OTJK7aLSUk3bjLml23SYhWSlmYbNghu3/2P3n4QO4s6+RAw1bMxEO0xr
        gvZThRcdllw+SQRY03VHzCiAAAYzKR8upy5strSbQfG9D38xHGb+A/Z6oSaJp4tR
        m+VknzINAgMBAAGgADANBgkqhkiG9w0BAQsFAAOCAQEALvDY6irBZJXuJ+AZ/5rL
        EEpWXl3f6ohdGkUE9oZFBsNQkCyejQbwYF4ujmxI7CqhZFrX6TA6KkjzDuWwqezt
        YcyYYBgxF8+HUO/66jseGuJiuPkeDQ5e2Kghit8PPutv9I1OVPaQkbNg6aDvaANT
        oB9IilYaxWM6en+RdtSg6p5dysfgOM3GbWqIjjZgU1rZsiuTOPRjxzXLc4Vq0v/A
        MvsV2OFBjcOPfqeTwuegl16reSy9+x79zmSfzapoji90Cc1hBQgqvPYCezEeuj+i
        hXQ3OSmKiyvSLJekdmgqdjsu7ks49Tm7wSUKC0QxlDh54k5Yo8uDM+4MLvOZOzL3
        FQ== -----END CERTIFICATE REQUEST-----\n
        """
      }
    })
  end

  defmodule AstarteMQTTV1CredentialsResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AstarteMQTTV1CredentialsResponse",
      type: :object,
      properties: %{
        client_crt: %Schema{type: :string}
      },
      example: %{
        client_crt: """
        -----BEGIN CERTIFICATE-----
        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
        ySj0xif2Z8U7MTfhmZs1cyDA/A== -----END CERTIFICATE-----\n
        """
      }
    })
  end

  defmodule AstarteMQTTV1VerifyCredentialsRequest do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AstarteMQTTV1VerifyCredentialsRequest",
      type: :object,
      properties: %{
        client_crt: %Schema{type: :string}
      },
      example: %{
        client_crt: """
        -----BEGIN CERTIFICATE-----
        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
        ySj0xif2Z8U7MTfhmZs1cyDA/A== -----END CERTIFICATE-----\n
        """
      }
    })
  end

  defmodule AstarteMQTTV1VerifyCredentialsResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AstarteMQTTV1VerifyCredentialsResponse",
      type: :object,
      properties: %{
        valid: %Schema{
          type: :boolean,
          description: "true if the credentials are valid, false otherwise"
        },
        timestamp: %Schema{
          type: :integer,
          description: "the timestamp of the credentials verification"
        },
        until: %Schema{
          type: :integer,
          description: "if the certificate is valid, the timestamp after which it will be invalid"
        },
        cause: %Schema{
          type: :string,
          description: "the reason the certificate is invalid"
        },
        details: %Schema{
          type: :string,
          description: "additional details on the verification"
        }
      }
    })
  end
end
