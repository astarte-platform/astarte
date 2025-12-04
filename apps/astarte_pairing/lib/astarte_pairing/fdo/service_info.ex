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
  alias Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfo
  alias Astarte.Pairing.FDO.OwnerOnboarding.OwnerServiceInfo
  alias Astarte.Core.Device
  alias Astarte.Pairing.Queries
  alias Astarte.Pairing.Engine
  alias Astarte.Pairing.Config

  @owner_max_service_info 4096

  def handle_msg_66(
        realm_name,
        session,
        %DeviceServiceInfoReady{
          replacement_hmac: replacement_hmac,
          max_owner_service_info_sz: nil
        }
      ) do
    handle_msg_66(
      realm_name,
      session,
      %DeviceServiceInfoReady{
        replacement_hmac: replacement_hmac,
        max_owner_service_info_sz: 1400
      }
    )
  end

  def handle_msg_66(
        realm_name,
        session,
        %DeviceServiceInfoReady{
          replacement_hmac: replacement_hmac,
          max_owner_service_info_sz: 0
        }
      ) do
    handle_msg_66(
      realm_name,
      session,
      %DeviceServiceInfoReady{
        replacement_hmac: replacement_hmac,
        max_owner_service_info_sz: 1400
      }
    )
  end

  def handle_msg_66(
        realm_name,
        session,
        %DeviceServiceInfoReady{
          replacement_hmac: replacement_hmac,
          max_owner_service_info_sz: device_max_size
        }
      ) do
    with {:ok, old_voucher} <-
           OwnershipVoucher.fetch(realm_name, session.device_id),
         {:ok, _new_voucher} <-
           OwnershipVoucher.generate_replacement_voucher(old_voucher, replacement_hmac),
         :ok <- Queries.update_session_max_payload(realm_name, session.key, device_max_size) do
      # TODO: Store `new_voucher` into DB.

      msg_67_payload = [@owner_max_service_info]

      {:ok, msg_67_payload}
    else
      _ ->
        {:error, :failed_66}
    end
  end

  # first device message, sending devmod
  def handle_message_68(
        realm_name,
        _session,
        %DeviceServiceInfo{is_more_service_info: false, service_info: service_info}
      ) do
    # TODO: make use of other device service info
    device_id = generate_device_id(service_info)
    encoded_device_id = Device.encode_device_id(device_id)

    with {:ok, credentials_secret} <- Engine.register_device(realm_name, encoded_device_id) do
      service_info = %{
        "astarte:active" => true,
        "astarte:realm" => realm_name,
        "astarte:secret" => credentials_secret,
        "astarte:baseurl" => "#{Config.base_url!()}",
        "astarte:deviceid" => encoded_device_id
      }

      service_info_keys = Map.keys(service_info)
      service_info_count = Enum.count(service_info_keys)

      # FIXME: this only works for single message service info
      modules = [service_info_count, service_info_count | service_info_keys]

      service_info
      |> Map.put("astarte:modules", modules)
      |> Map.put("astarte:nummodules", service_info_count)

      owner_service_info = %OwnerServiceInfo{
        is_more_service_info: false,
        is_done: true,
        service_info: service_info
      }

      response = OwnerServiceInfo.encode(owner_service_info)

      {:ok, response}

      # TODO uncomment and implement seriously this passage

      # if byte_size(encoded_cbor_list) <= session.max_service_info do

      # else
      #   <<trimmed_part::binary-size(session.max_service_info), rest::binary>> = encoded_cbor_list

      #   # Session.save_message_for_later_use(rest)
      #   # out of scope for now

      #   {:ok, trimmed_part}
      # end
    end
  end

  # all the others, awaiting for server message completion, out of scope
  # def handle_message_68(
  #       realm_name,
  #       session_max_service_info,
  #       session_remaining,
  #       %DeviceServiceInfo{is_more_service_info: false, service_info: []} = device_service_info
  #     ) do
  #   # max_service_info
  #   {:ok, session} = Session.fetch(realm_name, session_key)

  #   %OwnerServiceInfo{
  #     is_more_service_info: false,
  #     is_done: false,
  #     service_info: []
  #   }

  # end
  def handle_message_68(_realm_name, _session_key, _) do
    {:error, :invalid_payload}
  end

  defp generate_device_id(%{"devmod:sn" => sn}), do: UUID.uuid5(:oid, sn, :raw)
  defp generate_device_id(_), do: Device.random_device_id()
end
