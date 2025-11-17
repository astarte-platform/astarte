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
  alias Astarte.Pairing.Config

  def claim_ownership_voucher(realm_name, decoded_ownership_voucher, owner_private_key) do
    with {:ok, %{nonce: nonce, headers: headers}} <- hello() do
      owner_sign(realm_name, nonce, decoded_ownership_voucher, owner_private_key, headers)
    end
  end

  @doc """
  TO0.Hello - Type 20 message to initiate TO0 protocol.
  Sends an empty array as per FDO specification section 5.3.1.
  Returns decoded TO0.HelloAck (message 21) with rendezvous nonce.
  """
  def hello() do
    Rendezvous.send_hello()
  end

  @doc """
  TO0.OwnerSign - Type 22 message to register ownership.
  Sends ownership voucher and waits for response from rendezvous server.
  Returns decoded TO0.AcceptOwner (message 23) with negotiated wait time.
  """
  def owner_sign(realm_name, nonce, ownership_voucher, owner_private_key, headers) do
    with {:ok, addr_entries} <-
           RendezvousCore.get_rv_to2_addr_entry("#{realm_name}.#{Config.base_domain!()}") do
      request_body =
        RendezvousCore.build_owner_sign_message(
          ownership_voucher,
          owner_private_key,
          nonce,
          addr_entries
        )

      Rendezvous.register_ownership(request_body, headers)
    end
  end
end
