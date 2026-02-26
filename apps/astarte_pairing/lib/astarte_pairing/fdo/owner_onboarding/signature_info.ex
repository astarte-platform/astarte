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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.SignatureInfo do
  alias Astarte.Pairing.FDO.OwnershipVoucher
  alias COSE.Keys.ECC

  @type t :: :es256 | :es384 | :rs256 | :rs384 | {:eipd10, binary()} | {:eipd11, binary()}

  @type device_signature ::
          {:es256, struct()}
          | {:es384, struct()}
          | {:epid10, binary}
          | {:epid11, binary}

  @es256 -7
  @es384 -35
  @eipd10 90
  @eipd11 91

  def decode(sig_info) do
    case sig_info do
      [@es256, %CBOR.Tag{tag: :bytes, value: <<>>}] -> {:ok, :es256}
      [@es384, %CBOR.Tag{tag: :bytes, value: <<>>}] -> {:ok, :es384}
      [@eipd10, %CBOR.Tag{tag: :bytes, value: gid}] -> {:ok, {:eipd10, gid}}
      [@eipd11, %CBOR.Tag{tag: :bytes, value: gid}] -> {:ok, {:eipd11, gid}}
      _ -> :error
    end
  end

  def encode(sig_info) do
    case sig_info do
      :es256 -> [@es256, %CBOR.Tag{tag: :bytes, value: <<>>}]
      :es384 -> [@es384, %CBOR.Tag{tag: :bytes, value: <<>>}]
      {:eipd10, gid} -> [@eipd10, %CBOR.Tag{tag: :bytes, value: gid}]
      {:eipd11, gid} -> [@eipd11, %CBOR.Tag{tag: :bytes, value: gid}]
    end
  end

  def from_device_signature(device_signature) do
    case device_signature do
      {:es256, _} -> :es256
      {:es384, _} -> :es384
      epid -> epid
    end
  end

  @spec validate(t(), OwnershipVoucher.t()) :: {:ok, device_signature()} | :error
  def validate(sig_info, ownership_voucher) do
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

  def device_signature_to_database_params(device_signature) do
    case device_signature do
      {epid, gid} when epid in [:epid10, :epid11] ->
        %{sig_type: epid, epid_group: gid}

      {ec, pub_key} when ec in [:es256, :es384] ->
        %{sig_type: ec, device_public_key: :erlang.term_to_binary(pub_key)}
    end
  end

  def database_params_to_device_signature(device_params) do
    case device_params do
      %{sig_type: epid, epid_group: gid} when epid in [:epid10, :epid11] ->
        {:ok, {epid, gid}}

      %{sig_type: ec, device_public_key: device_pub} when ec in [:es256, :es384] ->
        {:ok, {ec, :erlang.binary_to_term(device_pub)}}

      _ ->
        :error
    end
  end

  defp parse_es256_key(pub_key) do
    case pub_key do
      {:ECPoint, <<4, x::binary-size(32), y::binary-size(32)>>} ->
        key =
          %ECC{
            alg: :es256,
            crv: :p256,
            x: x,
            y: y
          }

        {:ok, {:es256, key}}

      _ ->
        :error
    end
  end

  defp parse_es384_key(pub_key) do
    case pub_key do
      {:ECPoint, <<4, x::binary-size(48), y::binary-size(48)>>} ->
        key =
          %ECC{
            alg: :es384,
            crv: :p384,
            x: x,
            y: y
          }

        {:ok, {:es384, key}}

      _ ->
        :error
    end
  end
end
