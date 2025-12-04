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
  def counter_mode_kdf(mac_type, mac_subtype, n, secret, context, l) do
    do_counter_mode_kdf(mac_type, mac_subtype, 1, n + 1, secret, context, l, <<>>)
  end

  defp do_counter_mode_kdf(_mac_type, _mac_subtype, n, n, _secret, _context, _l, acc), do: acc

  defp do_counter_mode_kdf(mac_type, mac_subtype, i, n, secret, context, l, acc) do
    data = <<i::integer-unsigned-size(8), "FIDO-KDF"::binary, 0, context::binary, l::binary>>
    new_key = :crypto.mac(mac_type, mac_subtype, secret, data)
    acc = acc <> new_key

    do_counter_mode_kdf(mac_type, mac_subtype, i + 1, n, secret, context, l, acc)
  end
end
