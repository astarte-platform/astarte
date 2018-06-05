#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017-2018 Ispirata Srl
#

defmodule Astarte.Pairing.APIWeb.CredentialsStatusView do
  use Astarte.Pairing.APIWeb, :view
  alias Astarte.Pairing.APIWeb.CredentialsStatusView

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
    with {:ok, datetime} <- DateTime.from_unix(ms_epoch_timestamp, :milliseconds) do
      DateTime.to_string(datetime)
    else
      _ ->
        ""
    end
  end
end
