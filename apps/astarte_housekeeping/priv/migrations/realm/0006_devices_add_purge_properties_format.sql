CREATE TYPE capabilities (
  purge_properties_compression_format int
);

ALTER TABLE devices
ADD (
    capabilities capabilities
);
