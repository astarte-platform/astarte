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

defmodule Astarte.FDO.TO0 do
  @moduledoc """
  Main module for handling the FDO.TO0 protocol,
  in particular the function for claiming ownership of a device,
  as well as for sending the first message (TO0.Hello - Type 20) and
  the owner sign message (TO.OwnerSign - Type 22) to the rendezvous
  server.
  """

  alias Astarte.FDO.Config
  alias Astarte.FDO.Core.Rendezvous.RvTO2Addr
  alias Astarte.FDO.Rendezvous
  alias Astarte.FDO.Rendezvous.Core, as: RendezvousCore

  @default_wait_seconds 3600

  @doc """
  Claims an ownership voucher on the rendezvous server.

  Returns the instant at which the registration the server accepted stops being
  served, which may be earlier than the requested one.
  """
  def claim_ownership_voucher(
        realm_name,
        decoded_ownership_voucher,
        owner_private_key,
        opts \\ []
      ) do
    wait_seconds = Keyword.get(opts, :wait_seconds, @default_wait_seconds)

    with {:ok, %{nonce: nonce, headers: headers}} <- hello() do
      owner_sign(
        realm_name,
        nonce,
        decoded_ownership_voucher,
        owner_private_key,
        headers,
        wait_seconds
      )
    end
  end

  @doc """
  Revokes a previously claimed ownership voucher's registration on the
  rendezvous server.
  """
  def revoke_ownership_voucher(realm_name, decoded_ownership_voucher, owner_private_key) do
    with {:ok, _expiry} <-
           claim_ownership_voucher(realm_name, decoded_ownership_voucher, owner_private_key,
             wait_seconds: 0
           ) do
      :ok
    end
  end

  @spec expiry(non_neg_integer()) :: DateTime.t()
  defp expiry(wait_seconds) do
    DateTime.utc_now()
    |> DateTime.add(wait_seconds, :second)
    |> DateTime.truncate(:second)
  end

  @doc """
  TO0.Hello - Type 20 message to initiate TO0 protocol.
  Sends an empty array as per FDO specification section 5.3.1.
  Returns decoded TO0.HelloAck (message 21) with rendezvous nonce.
  """
  def hello do
    Rendezvous.send_hello()
  end

  @doc """
  TO0.OwnerSign - Type 22 message to register ownership.
  Sends ownership voucher and waits for response from rendezvous server.
  Returns the expiry of the registration, computed from the wait time
  negotiated in TO0.AcceptOwner (message 23).
  """
  def owner_sign(
        realm_name,
        nonce,
        ownership_voucher,
        owner_private_key,
        headers,
        wait_seconds \\ @default_wait_seconds
      ) do
    host = Config.base_url_host!()

    realm_rv_to2_addr_entry =
      RvTO2Addr.for_realm(
        realm_name,
        host.type,
        host.value,
        Config.base_url_port!(),
        Config.base_url_protocol!()
      )

    rv_to2_addr = [realm_rv_to2_addr_entry]

    with {:ok, request_body} <-
           RendezvousCore.build_owner_sign_message(
             ownership_voucher,
             owner_private_key,
             nonce,
             rv_to2_addr,
             wait_seconds
           ),
         {:ok, accepted_wait_seconds} <- Rendezvous.register_ownership(request_body, headers) do
      {:ok, expiry(accepted_wait_seconds)}
    end
  end
end
