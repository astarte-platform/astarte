import Config

config :astarte_appengine_api, Astarte.AppEngine.APIWeb.Endpoint,
  http: [port: 4001],
  server: false

config :astarte_appengine_api,
       :data_updater_plant_rpc_client,
       Astarte.AppEngine.API.RPC.DataUpdaterPlant.ClientMock

config :astarte_appengine_api,
       :vernemq_plugin_rpc_client,
       Astarte.AppEngine.API.RPC.VMQPlugin.ClientMock

config :astarte_appengine_api,
       :test_priv_key,
       {%{kty: :jose_jwk_kty_rsa},
        %{
          "d" =>
            "VJG98B1RkaSbUXykgVn72KT85Le9VN93BJiTAGkUp799ziY7k9vlAxj08_GFaa9gA0miIML74eAeq3FOudvHVQgxOuTZoD3WkhMyf5Qs3NgMMusWF2hrIVx40Du8siRVoE5LmnglipSWG_CWlOTj3wow1pfSVbOYYoNg2Lox_5tv3hoatJ9lMg5oim1eIRGezy99PL8Z2f2uINBx18Se0TO8zmdiL1qQTL2gktWCap-Ss4GIGzC1EY0VMmijUcB4qPFXfhjmq4o19IfFPc1zhO4rqbQqbFvYTDayGkAnGgMbtZLHCibCdxP10X6o4HHokq9RK0vrBPZ3APyMhCUhAQ",
          "dp" =>
            "XZAjPehIsOQmypqGsRODOTxLmevNIqwcvqLG5yq3mFevFgCMEzT30EO7B1LeMOGs2Rkc79p91otl_hHn6DM9KJ3PtZ2U5XxSq3nerZX97lIZHxBGaKxc6NWDaX-CEIOiLbHBtHZlc3Toj-8kMuoPixu07EJ2eIeBIIfwCAluQxU",
          "dq" =>
            "QxtJ1hjHUGX9G1zHZZpjUvG_ugqiygR1Q88rSQ5Qpjh634ms6HOQNCzJHPTJ_OxcI6a0Vu8nAj7iw49P1omioH__wZWkVw2mlIdyWPmMs-10CHZ5CLIBp01Sa-Gq-FjACzWDZ-uPh_xjm_G2F3y7gTG3BQ1jBtuY4_HH3F0Z10E",
          "e" => "AQAB",
          "kty" => "RSA",
          "n" =>
            "t3_eYliAJM2Pj-rChGlYnDssZKmqvVqWXAI78tAAr2FhyiD32N8n08YG0nSjGYBnfm_-MIY6A9S-obdUrp7g6wKYhVt5YZoCpMhWIvn4E0xkT0I4gNFnuUaAmWoxAWYUUC3wAR3eUuBf4a4LXrhNVOj6nbitJ4wJRfkuG9N5jovQTe9kKsrIQag5-ggbq8I87d0ACA_ZHiAxFmSbTSqzObcAESuGolSNfs17mS8NMs93O9Vpo2oVC5xYvdikfhouGcRBmjiU2b5GD-1Hcga968ejTi6XqLjwxSLF8SZ91Uf6ntXIihRcdNXy5DNb1-LLI4d4MwfOmrgnQwb7EA2nvQ",
          "p" =>
            "6dWekkuHJxZS1O5pNytgm0HCEb4ELtUvo16VZ0_fsly3yMe4a2WWhPCyBK9ZD2TfWizUUpWiqW3cnaSBoGDlQmJZjgvMSgLVJpibkZLy82Ch_Uy3vPCPwOta2WYK1iVCmjniowOP_Ao7MCK3arwvVvJSuffYgsv0Axhm20w82C0",
          "q" =>
            "yOTJtdhl489TIpa911OZEEpPX_aboNnGwBw91ttNL2V3yorhYx805kkH7OQoDzq3E-mkMx6FI2JVQLbWNGfCv-buelVLIP_s8PZN7qUusuSi2LEDr30mmtBDRtGJ9phN4Ul3qtt2VezFTRnMAAh0WiZbqiwoFs9l0vCnzqndt9E",
          "qi" =>
            "DflNIxvYciIgwd7aGeTfMTL0VpaeujzqYs4QMd0tE3ycZLRUM-s2vKPOjTPDJPUtFBgBjUYwVpbYzLLPepc5SrEddZHPy8s7UcNLzhdVk9ZuiN4ZPBJVlODuqKPtGmPxUKa--TPv8YPrC_ONEhZmuWBrsz9XgQByyPc7KAp-jns"
        }}

config :astarte_appengine_api, :test_pub_key_pem, """
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAt3/eYliAJM2Pj+rChGlY
nDssZKmqvVqWXAI78tAAr2FhyiD32N8n08YG0nSjGYBnfm/+MIY6A9S+obdUrp7g
6wKYhVt5YZoCpMhWIvn4E0xkT0I4gNFnuUaAmWoxAWYUUC3wAR3eUuBf4a4LXrhN
VOj6nbitJ4wJRfkuG9N5jovQTe9kKsrIQag5+ggbq8I87d0ACA/ZHiAxFmSbTSqz
ObcAESuGolSNfs17mS8NMs93O9Vpo2oVC5xYvdikfhouGcRBmjiU2b5GD+1Hcga9
68ejTi6XqLjwxSLF8SZ91Uf6ntXIihRcdNXy5DNb1+LLI4d4MwfOmrgnQwb7EA2n
vQIDAQAB
-----END PUBLIC KEY-----
"""

config :astarte_data_access, Astarte.DataAccess.Repo, log: false

config :astarte_data_updater_plant, :amqp_consumer_options,
  host: System.get_env("RABBITMQ_HOST") || "localhost"

config :astarte_data_updater_plant, :astarte_instance_id, "test"

config :astarte_data_updater_plant,
       :vernemq_plugin_rpc_client,
       Astarte.DataUpdaterPlant.RPC.VMQPlugin.ClientMock

config :astarte_data_updater_plant, :amqp_data_queue_total_count, 1
config :astarte_data_updater_plant, :amqp_data_queue_range_end, 0
config :astarte_data_updater_plant, :amqp_data_queue_range_start, 0

config :astarte_events, :connection_backoff, 0

config :astarte_secrets, vault_authentication_mechanism: :token
config :astarte_secrets, vault_token: "astarte_token"
config :astarte_secrets, vault_url: "http://localhost:8200"

config :astarte_secrets, vault_authentication_mechanism: :token
config :astarte_secrets, vault_token: "astarte_token"

config :astarte_housekeeping, Astarte.HousekeepingWeb.Endpoint,
  http: [port: 4001],
  server: false

config :astarte_secrets, vault_authentication_mechanism: :token
config :astarte_secrets, vault_token: "astarte_token"

config :astarte_data_access, Astarte.DataAccess.Repo, log: false

config :astarte_housekeeping,
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

config :astarte_housekeeping, :jwt_public_key_pem, """
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

config :astarte_pairing, Astarte.PairingWeb.Endpoint,
  http: [port: 4003],
  server: false

config :astarte_pairing, :rpc_client, MockRPCClient

config :astarte_pairing,
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

config :astarte_pairing, :jwt_public_key_pem, """
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

config :astarte_pairing, :agent_public_key_pems, [
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

config :astarte_pairing, :broker_url, "mqtts://broker.beta.astarte.cloud:8883/"

config :astarte_pairing,
       :cfssl_url,
       System.get_env("CFSSL_API_URL") || "http://localhost:8080"

config :astarte_pairing, :astarte_instance_id, "test"

config :astarte_pairing, :enable_fdo, true
config :astarte_pairing, :base_url_domain, "api.astarte.localhost"
config :astarte_pairing, :base_url_port, 4003
config :astarte_pairing, :base_url_protocol, :http
config :astarte_fdo, :base_url_domain, "api.astarte.localhost"
config :astarte_fdo, :base_url_port, 4003
config :astarte_fdo, :base_url_protocol, :http
config :astarte_pairing, :enable_credential_reuse, true

config :astarte_secrets, vault_authentication_mechanism: :token
config :astarte_secrets, vault_token: "astarte_token"

config :astarte_fdo, fdo_rendezvous_url: "http://localhost:8041"

config :bcrypt_elixir,
  log_rounds: 4

config :astarte_realm_management, Astarte.RealmManagementWeb.Endpoint,
  http: [port: 4001],
  server: false

config :astarte_realm_management,
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

config :astarte_realm_management, :test_pub_key_pem, """
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

config :astarte_secrets, vault_authentication_mechanism: :token
config :astarte_secrets, vault_token: "astarte_token"

config :astarte_trigger_engine, :amqp_consumer_options,
  host: System.get_env("RABBITMQ_HOST") || "rabbitmq"

config :astarte_trigger_engine, :events_consumer, MockEventsConsumer
config :astarte_trigger_engine, :astarte_instance_id, "test"

config :astarte_vmq_plugin, :amqp_options, host: System.get_env("RABBITMQ_HOST") || "localhost"

config :astarte_vmq_plugin, :queue_prefix, "test_data_queue_"

config :astarte_vmq_plugin, :registry_mfa, {Astarte.VMQ.Plugin.MockVerne, :get_functions, []}

config :astarte_vmq_plugin, :vernemq_api, MockVerneMQ.API

config :logger, :console, format: {PrettyLog.UserFriendlyFormatter, :format}

config :stream_data,
  max_runs: 50

config :ex_unit,
  timeout: 120_000
