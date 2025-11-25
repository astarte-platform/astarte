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

defmodule Astarte.Pairing.FDO.ServiceInfo do
  alias Astarte.Pairing.FDO.OwnershipVoucher
  alias Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfoReady

  @owner_max_service_info 4096

  def handle_msg_66(
        %DeviceServiceInfoReady{
          replacement_hmac: replacement_hmac,
          max_owner_service_info_sz: _device_max_size
        },
        %OwnershipVoucher{} = old_voucher
      ) do
    with {:ok, _new_voucher} <-
           OwnershipVoucher.generate_replacement_voucher(old_voucher, replacement_hmac) do
      # TODO: Store `new_voucher` and `device_max_size` in the Session or DB.

      msg_67_payload = [@owner_max_service_info]

      {:ok, generate_msg_67(msg_67_payload)}
    else
      _ ->
        {:error, :failed_66}
    end
  end

  def handle_msg_66(
        %DeviceServiceInfoReady{},
        _
      ) do
    {:error, :invalid_device_voucher}
  end

  def handle_msg_66(
        _,
        %OwnershipVoucher{}
      ) do
    {:error, :invalid_payload}
  end

  def generate_msg_67(payload) do
    CBOR.encode(payload) |> COSE.tag_as_byte()
  end
end
