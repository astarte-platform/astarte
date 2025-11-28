CREATE TABLE :keyspace.to2_sessions (
  session_key blob,
  sig_type int,
  epid_group blob,
  device_id uuid,
  device_public_key blob,
  prove_dv_nonce blob,
  kex_suite_name ascii,
  cipher_suite_name ascii,
  owner_random blob,
  secret blob,
  sevk blob,
  svk blob,
  sek blob,
  PRIMARY KEY (session_key)
);
