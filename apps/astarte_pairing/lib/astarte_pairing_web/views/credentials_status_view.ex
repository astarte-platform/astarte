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

defmodule Astarte.PairingWeb.CredentialsStatusView do
  use Astarte.PairingWeb, :view

  alias Astarte.PairingWeb.CredentialsStatusView

  def render("show_astarte_mqtt_v1.json", %{credentials_status: credentials_status}) do
    %{
      data:
        render_one(
          credentials_status,
          CredentialsStatusView,
          "astarte_mqtt_v1_credentials_status.json"
        )
    }
  end

  def render("astarte_mqtt_v1_credentials_status.json", %{
        credentials_status: %{valid: true} = credentials_status
      }) do
    %{
      valid: credentials_status.valid,
      timestamp: to_datetime_string(credentials_status.timestamp),
      until: to_datetime_string(credentials_status.until)
    }
  end

  def render("astarte_mqtt_v1_credentials_status.json", %{
        credentials_status: %{valid: false} = credentials_status
      }) do
    %{
      valid: credentials_status.valid,
      timestamp: to_datetime_string(credentials_status.timestamp),
      cause: credentials_status.cause,
      details: credentials_status.details
    }
  end

  defp to_datetime_string(ms_epoch_timestamp) when is_integer(ms_epoch_timestamp) do
    case DateTime.from_unix(ms_epoch_timestamp, :millisecond) do
      {:ok, datetime} ->
        DateTime.to_string(datetime)

      _ ->
        ""
    end
  end
end
