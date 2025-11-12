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

defmodule Astarte.Pairing.FDO do
  alias Astarte.Pairing.FDO.Rendezvous
  alias Astarte.Pairing.FDO.Rendezvous.Core, as: RendezvousCore
  alias Astarte.Pairing.Queries

  def claim_voucher(realm_name, device_id) do
    with {:ok, nonce} <- hello(),
         {:ok, owner_private_key} <- Queries.get_owner_private_key(realm_name, device_id),
         {:ok, ownership_voucher} <- Queries.get_ownership_voucher(realm_name, device_id) do
      owner_sign(nonce, ownership_voucher, owner_private_key, [])
    end
  end

  @doc """
  TO0.Hello - Type 20 message to initiate TO0 protocol.
  Sends an empty array as per FDO specification section 5.3.1.
  Returns decoded TO0.HelloAck (message 21) with rendezvous nonce.
  """
  def hello() do
    with {:ok, body} <- Rendezvous.send_hello() do
      RendezvousCore.get_body_nonce(body)
    end
  end

  @doc """
  TO0.OwnerSign - Type 22 message to register ownership.
  Sends ownership voucher and waits for response from rendezvous server.
  Returns decoded TO0.AcceptOwner (message 23) with negotiated wait time.
  """

  def owner_sign(nonce, ownership_voucher, owner_private_key, headers) do
    # TODO: not sure about this string "entries" content, is it something we want parametrized?
    with {:ok, addr_entries} <-
           RendezvousCore.get_rv_to2_addr_entries("first entry", "second entry"),
         {:ok, request_body} <-
           RendezvousCore.build_owner_sign_message(
             ownership_voucher,
             owner_private_key,
             nonce,
             addr_entries
           ) do
      Rendezvous.register_ownership(request_body, headers)
    end
  end
end
