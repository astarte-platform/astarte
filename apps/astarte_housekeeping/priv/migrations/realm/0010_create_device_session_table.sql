CREATE TABLE :keyspace.to2_sessions (
  session_key blob,
  device_id uuid,
  private_key blob,
  public_key blob,
  PRIMARY KEY (session_key)
);
