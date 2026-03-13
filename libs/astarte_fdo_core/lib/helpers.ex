#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.FDO.Core.Helpers do
  @moduledoc """
  Helper functions for FDO Core, including signature info validation
  and device public key parsing utilities.
  """

  alias Astarte.FDO.Core.OwnershipVoucher
  alias COSE.Keys.ECC

  @type t :: :es256 | :es384 | :rs256 | :rs384 | {:eipd10, binary()} | {:eipd11, binary()}

  @type device_signature ::
          {:es256, struct()}
          | {:es384, struct()}
          | {:epid10, binary()}
          | {:epid11, binary()}

  @spec validate_signature_info(t(), OwnershipVoucher.t()) :: {:ok, device_signature()} | :error
  def validate_signature_info(sig_info, ownership_voucher) do
    with {:ok, device_public_key} <- OwnershipVoucher.device_public_key(ownership_voucher) do
      case {sig_info, device_public_key} do
        {{:eipd10, _gid}, nil} -> {:ok, sig_info}
        {{:eipd11, _gid}, nil} -> {:ok, sig_info}
        {_, nil} -> :error
        {:es256, pub_key} -> parse_es256_key(pub_key)
        {:es384, pub_key} -> parse_es384_key(pub_key)
        _ -> :error
      end
    end
  end

  defp parse_es256_key(pub_key) do
    case pub_key do
      {:ECPoint, <<4, x::binary-size(32), y::binary-size(32)>>} ->
        key = %ECC{alg: :es256, crv: :p256, x: x, y: y}
        {:ok, {:es256, key}}

      _ ->
        :error
    end
  end

  defp parse_es384_key(pub_key) do
    case pub_key do
      {:ECPoint, <<4, x::binary-size(48), y::binary-size(48)>>} ->
        key = %ECC{alg: :es384, crv: :p384, x: x, y: y}
        {:ok, {:es384, key}}

      _ ->
        :error
    end
  end
end
