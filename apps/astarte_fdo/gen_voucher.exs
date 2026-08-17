# Usage:
#   mix run gen_voucher.exs [owner_key.pem] [output_voucher.pem]
#
# Must be run with MIX_ENV=test (test support modules required):
#   MIX_ENV=test mix run gen_voucher.exs
#   MIX_ENV=test mix run gen_voucher.exs /path/to/key.pem /path/to/out.pem

[key_path, out_path] =
  case System.argv() do
    [k, o] -> [k, o]
    [k]    -> [k, "test_voucher.pem"]
    []     -> ["owner_key.pem", "test_voucher.pem"]
  end

key_path = Path.expand(key_path)
out_path = Path.expand(out_path)

unless File.exists?(key_path) do
  IO.puts(:stderr, "Error: key file not found: #{key_path}")
  System.halt(1)
end

IO.puts("Reading owner key from: #{key_path}")

owner_key_pem = File.read!(key_path)

{:ok, owner_key} = COSE.Keys.from_pem(owner_key_pem)

{voucher, _} =
  case owner_key do
    %COSE.Keys.RSA{} ->
      Astarte.FDO.Helpers.generate_rsapss_data_and_pem(owner_key: owner_key)

    %COSE.Keys.ECC{} ->
      Astarte.FDO.Helpers.generate_voucher_data_and_pem(owner_key: owner_key)
  end

voucher_pem = Astarte.FDO.Helpers.voucher_to_pem(voucher)

File.write!(out_path, voucher_pem)
IO.puts("Done — voucher written to: #{out_path}")
