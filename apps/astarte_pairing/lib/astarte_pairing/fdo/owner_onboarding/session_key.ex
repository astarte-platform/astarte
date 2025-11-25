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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.SessionKey do
  alias COSE.Keys.ECC

  def new("ECDH256", %ECC{} = owner_key) do
    random = :crypto.strong_rand_bytes(16)
    xa = random_ecdh(owner_key, random)

    {:ok, random, xa}
  end

  defp random_ecdh(key, random) do
    blen_r = byte_size(random)
    blen_x = byte_size(key.x)
    blen_y = byte_size(key.y)

    <<blen_x::integer-unsigned-size(16), key.x::binary, blen_y::integer-unsigned-size(16),
      key.y::binary, blen_r::integer-unsigned-size(16), random::binary>>
  end

  def compute_shared_secret("ECDH256", %ECC{} = owner_key, owner_random, xb) do
    {device_random, device_public} = parse_xb_ecdh(xb)
    shse = shared_secret_ecdh(owner_key, owner_random, device_random, device_public)
    {:ok, device_public, shse}
  end

  defp parse_xb_ecdh(xb) do
    <<blen_x::integer-unsigned-size(16), rest::binary>> = xb
    <<x::binary-size(blen_x), rest::binary>> = rest
    <<blen_y::integer-unsigned-size(16), rest::binary>> = rest
    <<y::binary-size(blen_y), rest::binary>> = rest
    <<blen_r::integer-unsigned-size(16), rest::binary>> = rest
    <<device_random::binary-size(blen_r)>> = rest

    device_public = <<4, x::binary, y::binary>>

    {device_random, device_public}
  end

  defp shared_secret_ecdh(owner_key, owner_random, device_random, device_public) do
    point = {:ECPoint, device_public}
    shared_secret = :public_key.compute_key(point, owner_key.pem_record)

    <<shared_secret::binary, device_random::binary, owner_random::binary>>
  end
end
