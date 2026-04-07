ALTER TABLE :keyspace.ownership_vouchers
ADD (
  replacement_guid blob,
  replacement_rendezvous_info blob,
  replacement_public_key blob,
  output_voucher blob,
  key_name varchar,
  key_algorithm int,
  user_id blob
);
