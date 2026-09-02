defmodule Astarte.Housekeeping.Migrations.MigrateOwnershipVouchersToAstarteKeyspace do
  use Ecto.Migration

  @moduledoc """
  Migrates ownership_vouchers from realm keyspaces to the astarte keyspace.
  Adds the realm field to each record.
  """

  @disable_ddl_transaction true

  def up do
    # Get all realm names from the realms table
    realms = Repo.query!("SELECT realm_name FROM realms")

    # For each realm, migrate its ownership_vouchers to astarte keyspace
    for %{"realm_name" => realm_name} <- realms do
      migrate_realm_ownership_vouchers(realm_name)
    end
  end

  defp migrate_realm_ownership_vouchers(realm_name) do
    keyspace_name = Astarte.DataAccess.Realms.Realm.keyspace_name(realm_name)
    astarte_keyspace = Astarte.DataAccess.Realms.Realm.astarte_keyspace_name()

    # Read all ownership vouchers from the realm keyspace
    # Check if table exists first
    query = "SELECT guid, voucher_data, key_name, key_algorithm, replacement_guid, replacement_rendezvous_info, replacement_public_key, output_voucher, user_id FROM #{keyspace_name}.ownership_vouchers"
    
    try do
      vouchers = Repo.query!(query)
      
      for voucher <- vouchers do
        # Insert into astarte keyspace with realm field
        insert_query = """
          INSERT INTO #{astarte_keyspace}.ownership_vouchers (
            guid, realm, status, voucher_data, output_voucher, 
            user_id, key_name, key_algorithm, 
            replacement_guid, replacement_rendezvous_info, replacement_public_key
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        # Default values for new fields
        Repo.execute(insert_query, [
          voucher["guid"],
          realm_name,
          0,  # status: created
          voucher["voucher_data"],
          voucher["output_voucher"],
          voucher["user_id"],
          voucher["key_name"] || "",
          voucher["key_algorithm"] || 0,
          voucher["replacement_guid"],
          voucher["replacement_rendezvous_info"],
          voucher["replacement_public_key"]
        ])
      end
    rescue
      e ->
        # Table might not exist in this realm keyspace, skip
        IO.puts("Skipping realm #{realm_name}: #{e.message}")
    end
  end

  def down do
    # This migration is not easily reversible
    # The data in astarte keyspace would need to be deleted per realm
    raise "Migration not reversible"
  end
end