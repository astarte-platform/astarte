CREATE TABLE :keyspace.ownership_vouchers (
  private_key blob,
  voucher_data blob,
  device_id uuid,
  PRIMARY KEY (device_id, voucher_data)
);
