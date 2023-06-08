#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :astarte_pairing_api, Astarte.Pairing.APIWeb.Endpoint,
  http: [port: 4001],
  server: false

config :logger, :console,
  format: {PrettyLog.UserFriendlyFormatter, :format},
  metadata: [
    :method,
    :request_path,
    :status_code,
    :elapsed,
    :realm,
    :hw_id,
    :function,
    :request_id,
    :tag
  ]

config :astarte_rpc, :amqp_connection, host: System.get_env("RABBITMQ_HOST") || "rabbitmq"

config :astarte_pairing_api, :rpc_client, MockRPCClient

config :astarte_pairing_api,
       :test_priv_key,
       {%{kty: :jose_jwk_kty_rsa},
        %{
          "d" =>
            "NTf4ag6B51NL-p-ZIft2iCypIKkniAJST2gmuFexSsCJRn8tIk66hcdySMKBaof6uM1nT18MyS-qCZLFxRe630Gba-fewMDmkgEdNBfgEQfbrb-ff829-ojgqxuNWW873V6p13vfPhuByMg84OInr3q70EfT3GG0wXAxQhRdsYg_faja6LX-YBAzeEcXkbhNj7H-PmwfCvKo-hV7iiPOLiVCqVY3n2jlruVEazG9oO8M8Tq6z0CgVKxozpHdA8L6ZEbRKPkJRSPrX_nscIEMLj4vdQjFwBw3fr_aP8Ty99rRmyAHp7uRj7rtlMLecFJm6MLkJ5pq6zNua3cnQ7vnoQ",
          "dp" =>
            "jJ4IXK6nsOgY1CZBIrfmo_5ki13trb6G7rAIF62-tfLiqaeTXb9GKLDxSKBdUQ6ZB6vnusU8PcgNoiIH4VAtK64oPRZjFZmUiPGo_CfIBENXN9KLRiL6m9lHLYmFiJWS3JRyCfEnJWQB-A8OLCx_yRoJmxeK2WhlOWisq1twu18",
          "dq" =>
            "DnlmkvXj82LOKEZPcD8rmxh4vlhuHgnWy3MKfGHLCgrJb1F9tJeOUuh0RA_Qb9-yRQKBJCuQLT40KoNIbmDbrC8fFfHedXf9lFnebdc9OjlD8carmR60E2hCiABfeHJRJso2Diti7J_MKkpOYWKCTcevvYPLcjCZZtDoORRnqW0",
          "e" => "AQAB",
          "kty" => "RSA",
          "n" =>
            "vxc_7iTcAd5FprvGWQtlbhBJy2gv0QLk0GcXg6cK-XYne7bkXJ_2ada1cQDfQAiZ9XRN04sGyrVCY0IjAbRChkMjJFhYF1WMWv7PiybTaRSn8KyJG9g_Zpje5hVTYjBvfGqym3yWf0f6rJpAbCdkgRJkWvBLA2NgCX6pzQZWJTsItnUp3aaCt0lOw3ZKc-ZMvuP6S1GahW0kSFV7jPJXJOYU76KvYgkkqrXdTe2nzyOEn0YLEboojtPp6ZylQWxxoTz3vFcjIrVf53g1AB5f4ua_ACmqSZyF7I6Cceyo93q4rpg2wCGFANxG1qgD3tXATQI8PJloz7eN-BjC-D3JOw",
          "p" =>
            "9nQaxgbHwWWaR-R8sI6TGMUQkrCgHeDTuGGzXJR_LEWIwa4_6Vfs1JUDpWUcdKifXiKDsroIKun8RuWfJi6AsaQADLJ3y3P_AQj9E03__JKPVww93e9ea--6DRS-ldRw0BCj-BuOeuIuL1d2OMX258-oL0YnEihlnCeAzDyTZ38",
          "q" =>
            "xn4njWPYbaPWz4vZkXgJjJ6NP4pj4BJB9RA6QDBk6acoILnT3VsPgYPJLKBNHuprfp82FgAgLw2FXk2d2Ik-P3d4bHjezl3oIIojqRhuNqpasTwffI-gHqigt5JD3FACM7ZWDNOLORaYIw77N0ajnHiAaZxO9Tw95JcCaOtPHEU",
          "qi" =>
            "mb3tAXjpvnrRD0S4Ag6Xv5IBk4cExwWM-hpmK5ASc-fSmIZAG26VK-ctfYQ-q1JINx0u87bTKbxptjpxpIBIJxvZ6DsjXahAtYdMchUKp-x0R4Lw2QppsnS1ulUHUs7GrP2x_g5bURai4BVcEzfU4MmaWQZyfGC8I84-Ef3V3l0"
        }}

config :astarte_pairing_api, :agent_public_key_pems, [
  """
  -----BEGIN PUBLIC KEY-----
  MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvxc/7iTcAd5FprvGWQtl
  bhBJy2gv0QLk0GcXg6cK+XYne7bkXJ/2ada1cQDfQAiZ9XRN04sGyrVCY0IjAbRC
  hkMjJFhYF1WMWv7PiybTaRSn8KyJG9g/Zpje5hVTYjBvfGqym3yWf0f6rJpAbCdk
  gRJkWvBLA2NgCX6pzQZWJTsItnUp3aaCt0lOw3ZKc+ZMvuP6S1GahW0kSFV7jPJX
  JOYU76KvYgkkqrXdTe2nzyOEn0YLEboojtPp6ZylQWxxoTz3vFcjIrVf53g1AB5f
  4ua/ACmqSZyF7I6Cceyo93q4rpg2wCGFANxG1qgD3tXATQI8PJloz7eN+BjC+D3J
  OwIDAQAB
  -----END PUBLIC KEY-----
  """
]
