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

defmodule Astarte.PairingWeb.CredentialsView do
  use Astarte.PairingWeb, :view
  alias Astarte.PairingWeb.CredentialsView

  def render("show_astarte_mqtt_v1.json", %{credentials: credentials}) do
    %{data: render_one(credentials, CredentialsView, "astarte_mqtt_v1_credentials.json")}
  end

  def render("astarte_mqtt_v1_credentials.json", %{credentials: credentials}) do
    %{client_crt: credentials.client_crt}
  end
end
