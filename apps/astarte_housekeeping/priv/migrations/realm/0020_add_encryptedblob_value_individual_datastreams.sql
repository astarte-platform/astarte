ALTER TABLE :keyspace.individual_datastreams
ADD (
   encryptedblob_value blob,
   encrypted_dek blob
);
