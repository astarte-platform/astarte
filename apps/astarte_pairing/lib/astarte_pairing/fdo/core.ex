#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.Pairing.FDO.Core do
  require Logger

  @spec extract_private_key(String.t()) :: {:ok, :public_key.private_key()} | {:error, term()}
  def extract_private_key(private_key_pem) do
    :public_key.pem_decode(private_key_pem)
    |> Enum.find(fn {asn1_type, _, _} -> asn1_type in [:ECPrivateKey, :PrivateKeyInfo] end)
    |> case do
      nil -> {:error, :invalid_pem}
      entry -> safe_decode_pem_entry(entry)
    end
  end

  defp safe_decode_pem_entry(entry) do
    try do
      {:ok, :public_key.pem_entry_decode(entry)}
    rescue
      e ->
        Logger.warning("pem_entry_decode failed: #{inspect(e)}")
        {:error, :pem_entry_decoding_failed}
    end
  end
end
