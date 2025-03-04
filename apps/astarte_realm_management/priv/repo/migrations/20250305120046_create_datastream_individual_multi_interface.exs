defmodule Astarte.RealmManagement.Repo.Migrations.CreateDatastreamIndividualMultiInterface do
  use Ecto.Migration

  def up do
    create table("individual_datastreams", primary_key: false) do
      add(:device_id, :uuid, primary_key: true)
      add(:interface_id, :uuid, primary_key: true)
      add(:endpoint_id, :uuid, primary_key: true)
      add(:path, :varchar, primary_key: true)
      add(:value_timestamp, :timestamp, partition_key: true)
      add(:reception_timestamp, :timestamp, partition_key: true)
      add(:reception_timestamp_submillis, :smallint, partition_key: true)

      add(:double_value, :double)
      add(:integer_value, :int)
      add(:boolean_value, :boolean)
      add(:longinteger_value, :bigint)
      add(:string_value, :varchar)
      add(:binaryblob_value, :blob)
      add(:datetime_value, :timestamp)
      add(:doublearray_value, :"list<double>")
      add(:integerarray_value, :"list<int>")
      add(:booleanarray_value, :"list<boolean>")
      add(:longintegerarray_value, :"list<bigint>")
      add(:stringarray_value, :"list<varchar>")
      add(:binaryblobarray_value, :"list<blob>")
      add(:datetimearray_value, :"list<timestamp>")
    end
  end
end
