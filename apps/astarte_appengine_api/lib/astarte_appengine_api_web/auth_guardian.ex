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
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.AppEngine.APIWeb.AuthGuardian do
  use Guardian, otp_app: :astarte_appengine_api

  alias Astarte.AppEngine.API.Auth.User

  def subject_for_token(%User{id: id}, _claims) do
    {:ok, to_string(id)}
  end

  def resource_from_claims(claims) do
    {:ok,
     %User{
       id: claims["sub"],
       authorizations: Map.get(claims, "a_aea", [])
     }}
  end
end
