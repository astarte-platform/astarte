CREATE TABLE :keyspace.to2_sessions (
  session_key blob,
  device_id uuid,
  device_public_key blob,
  prove_dv_nonce blob,
  kex_suite_name ascii,
  owner_random blob,
  secret blob,
  PRIMARY KEY (session_key)
);
