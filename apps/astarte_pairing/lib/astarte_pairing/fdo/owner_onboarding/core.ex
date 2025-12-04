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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.Core do
  # h – The length of the output of a single invocation of the PRF in bits
  # r – The length of the binary representation of the counter i
  # l_bits - The length of the binary representation of L 
  # l - is passed in binary
  def counter_mode_kdf(h, r, l_bits, mac_type, mac_subtype, k_in, label, context, l) do
    if h == 0 do
      {:error, :unspecified}
    else
      n = ceil(l / h)

      if n > Integer.pow(2, r) - 1 do
        {:error, :unspecified}
      else
        l_2 = <<l::integer-big-unsigned-size(l_bits)>>

        do_counter_mode_kdf(<<>>, n, 1, r, mac_type, mac_subtype, k_in, label, context, l_2)
        |> binary_part(0, div(l, 8))
      end
    end
  end

  defp do_counter_mode_kdf(
         result,
         0,
         _i,
         _r,
         _mac_type,
         _mac_subtype,
         _k_in,
         _label,
         _context,
         _l_2
       ) do
    result
  end

  defp do_counter_mode_kdf(result, n, i, r, mac_type, mac_subtype, k_in, label, context, l_2) do
    i_2 = <<i::integer-big-unsigned-size(r)>>

    # [i]2 || Label || 0x00 || Context || [L]2
    data = i_2 <> <<label::binary>> <> <<0x00>> <> <<context::binary>> <> l_2

    # K(i)
    k_of_i = :crypto.mac(mac_type, mac_subtype, k_in, data)

    result = result <> k_of_i

    do_counter_mode_kdf(result, n - 1, i + 1, r, mac_type, mac_subtype, k_in, label, context, l_2)
  end
end
