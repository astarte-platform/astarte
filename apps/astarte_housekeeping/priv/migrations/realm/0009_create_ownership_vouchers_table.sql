CREATE TABLE :keyspace.ownership_vouchers (
  private_key blob,
  voucher_data blob,
  guid blob,
  PRIMARY KEY (guid)
);
