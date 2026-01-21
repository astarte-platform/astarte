CREATE TABLE :keyspace.to2_sessions (
  guid blob,
  device_id uuid,
  nonce blob,
  sig_type int,
  epid_group blob,
  device_public_key blob,
  prove_dv_nonce blob,
  setup_dv_nonce blob,
  kex_suite_name ascii,
  cipher_suite_name int,
  max_owner_service_info_size int,
  owner_random blob,
  secret blob,
  sevk blob,
  svk blob,
  sek blob,
  device_service_info map<tuple<text, text>, blob>,
  owner_service_info list<blob>,
  last_chunk_sent int,
  PRIMARY KEY (guid)
)
WITH default_time_to_live = 7200;
