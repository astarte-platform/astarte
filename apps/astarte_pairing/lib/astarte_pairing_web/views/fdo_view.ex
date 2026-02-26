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

defmodule Astarte.PairingWeb.FDOView do
  use Astarte.PairingWeb, :view

  alias Astarte.Pairing.FDO.OwnerOnboarding.Session
  alias Astarte.Pairing.FDO.Types.Error

  def render("default.cbor", %{cbor_response: response}) do
    response
  end

  def render("secure.cbor", %{response: response} = assigns) do
    session = assigns.to2_session
    Session.encrypt_and_sign(session, CBOR.encode(response))
  end

  def render("secure.cbor", %{cbor_response: response} = assigns) do
    session = assigns.to2_session
    Session.encrypt_and_sign(session, response)
  end

  def render("error.cbor", assigns) do
    %{error_code: error_code, correlation_id: correlation_id, message_id: message_id} = assigns

    %Error{
      error_code: error_code,
      previous_message_id: message_id,
      error_message: "",
      timestamp: nil,
      correlation_id: correlation_id
    }
    |> Error.encode_cbor()
  end
end
