use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :astarte_appengine_api, Astarte.AppEngine.APIWeb.Endpoint,
  http: [port: 4001],
  server: false

config :cqerl,
  cassandra_nodes: [
    {System.get_env("CASSANDRA_DB_HOST") || "cassandra",
     System.get_env("CASSANDRA_DB_PORT") || 9042}
  ]

# Print only warnings and errors during test
config :logger, level: :warn

config :astarte_rpc, :amqp_connection, host: System.get_env("RABBITMQ_HOST") || "rabbitmq"

config :astarte_appengine_api, :rpc_client, MockRPCClient

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
