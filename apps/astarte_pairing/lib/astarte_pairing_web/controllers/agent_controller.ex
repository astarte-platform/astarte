#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
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

defmodule Astarte.PairingWeb.AgentController do
  use Astarte.PairingWeb, :controller

  alias Astarte.Pairing.Agent
  alias Astarte.Pairing.Agent.DeviceRegistrationResponse

  action_fallback Astarte.PairingWeb.FallbackController

  def create(conn, %{"realm_name" => realm, "data" => params}) do
    with {:ok, %DeviceRegistrationResponse{} = response} <- Agent.register_device(realm, params) do
      conn
      |> put_status(:created)
      |> render("show.json", device_registration_response: response)
    end
  end

  def delete(conn, %{"realm_name" => realm, "device_id" => device_id}) do
    with :ok <- Agent.unregister_device(realm, device_id) do
      conn
      |> resp(:no_content, "")
    end
  end
end
