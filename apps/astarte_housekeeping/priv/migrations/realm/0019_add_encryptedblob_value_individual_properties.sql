ALTER TABLE :keyspace.individual_properties
ADD (
   encryptedblob_value blob,
   encrypted_dek blob
);
