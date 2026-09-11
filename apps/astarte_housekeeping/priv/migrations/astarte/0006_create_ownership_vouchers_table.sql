CREATE TABLE :keyspace.ownership_vouchers (
  guid blob,
  realm text,
  status int,
  voucher_data blob,
  output_voucher blob,
  user_id blob,
  key_name text,
  key_algorithm int,
  replacement_guid blob,
  replacement_rendezvous_info blob,
  replacement_public_key blob,
  PRIMARY KEY (guid)
);