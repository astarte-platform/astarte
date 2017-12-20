use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :astarte_pairing_api, Astarte.Pairing.APIWeb.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

config :astarte_rpc, :amqp_connection,
  host: "rabbitmq"

config :astarte_pairing_api, :jwt_public_key,
  # The public key for the private key found below
  %{"e" => "AQAB",
    "kty" => "RSA",
    "n" => "9skBBt-9MkjhJos5bLBtmseZihmMGQJ2O117UJe_FDO349WQypecBf-_G7Vlq-HkvK_8rqmWLBP0ywaueDvfeSYzREuJkfGG49diJ0uZHSYsq4WUaENYfUVeVBk5oeN1zbkkmkpKKwRfkFiMS1YDqfAd_d2fQOGkAlMhAuCpYi5Y-5sG5ScUe-Fypc83i8M_wZbUHTjg6sSoBsqrGlo4yWOqI3jPnPcI1xSCz6YB2pQeFYkb4mpR4b4VfMURGbitJ9O6teEl9arXisSBwIG_W35OAqjaivIDngn91gF0W5ywodyen4td-7R5DH_kxlyBJihvbdNraDw6P1NY7v3tyw"}

config :astarte_pairing_api, Astarte.Pairing.APIWeb.TestJWTProducer,
  allowed_algos: ["RS256"],
  secret_key:
    %{"d" => "JSXCks9RAmW4Bn5EiZjRFtBey0vnK8iUFYGP02TULW1Pi-sU3XoO0VRa5wfaIxJgxQpUpdH_OelTGtCJqK2SiQD4DJq2PZK2tEsyiim2BY4-gR8dZMhmZIzxkwUtCLJdhDcPTG5MVcdVvzuk-p4a9RSg3xriIvkUIAl1WaKJvK5jqCzJSZzui8up1UGWu2C1lT_9rIM58yRCdfe6AiP9Ozniw-qs6ySZse6pRXeKOelcmt0qB3dO9OcUmejNKmcte2GPZYUJrw5nz0aZzRmH10kQPz5INSaR21D_cMtbi2O3k1uDHjw4rSwbdSj7xN07548PjnffSeYSj3jXvv56iQ",
      "dp" => "rnJLKBSSF7hlOX67MElFWBgra79S0hISgHll4o7a3MD6QC0PhLYEt8NBI-pZhNL3EqWr1d4dOkStKT3qcF32zO4xmwtTeYnnWoOu-dkiptTCY00CENLDZgaOMHTuVjcg1SO7F1gZzIxK9fSONsRMnxa9JA9-sj4oCMYfAqkmyak",
      "dq" => "SI-cULct-57Sx-jl2G7VWILsEBAhjmaNuwUNNsxFavhmN3cTvIWqZJo5YMqzbZKqgK9y0l-QVd_euDP-oEX7QpICz7nwVMgqfafzcxYGpPEvCc9OxlitInwdA6SMbtW_8k9qSrWo7RYzTWdDjka3rngBFYOntEjemM0KvYmmkMs",
      "e" => "AQAB",
      "kty" => "RSA",
      "n" => "9skBBt-9MkjhJos5bLBtmseZihmMGQJ2O117UJe_FDO349WQypecBf-_G7Vlq-HkvK_8rqmWLBP0ywaueDvfeSYzREuJkfGG49diJ0uZHSYsq4WUaENYfUVeVBk5oeN1zbkkmkpKKwRfkFiMS1YDqfAd_d2fQOGkAlMhAuCpYi5Y-5sG5ScUe-Fypc83i8M_wZbUHTjg6sSoBsqrGlo4yWOqI3jPnPcI1xSCz6YB2pQeFYkb4mpR4b4VfMURGbitJ9O6teEl9arXisSBwIG_W35OAqjaivIDngn91gF0W5ywodyen4td-7R5DH_kxlyBJihvbdNraDw6P1NY7v3tyw",
      "p" => "_ZNJOeFfp2QtY7164OX4Q04Ai2w6A8Z5LwwyzoxqIbQ0MvZPwJ5-VcicNZ7Ydv3gNk8ZCZthSieVg3ybwAt81MAXT0g0cn_xTr-4wrwPN4oKPldnc_BaQzdigiK4U7PdDCph1rRourp8lsKwg9XpMYr9AaxGpQgE2rUgz-hu2e0",
      "q" => "-SUYwADXRxUaVo74tUoSsBtQqUP0chzyCDgDRUR49-_QW5ipQenNMqqak53TO8edpwyWZx5jZ3p5tDQT2o-jn6nN8R9YYhPCiudE6alaZfUwf6miAI5S9QFZEU8zUguZQ0fiaglpGFu-weU3E_l7J2oZNWd3FjR7CizRUdVgj5c",
      "qi" => "3JWo9p2SSlsbFvhXsFA2zkvpmNk8huOkqM7eJGhBwpllA6WGOr4uiY1OaInYdYYgGF7FgV8CIWamkq4uiUkK7R8YLTDwtKfSHzQyyvTRQM_2vTwNgJVilkxfeeDFxo3q4OZD5tdUYThRZJQR3SzEO43xAkfjlaMJPOMGiUPv-Y8"}
