#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.AppEngine.APIWeb.SocketGuardian do
  use Guardian, otp_app: :astarte_appengine_api

  alias Astarte.AppEngine.API.Auth.RoomsUser

  def subject_for_token(%RoomsUser{id: id}, _claims) do
    {:ok, to_string(id)}
  end

  def resource_from_claims(claims) do
    channels_authz = Map.get(claims, "a_ch", [])

    join_authz =
      channels_authz
      |> extract_authorization_paths("JOIN")

    watch_authz =
      channels_authz
      |> extract_authorization_paths("WATCH")

    {:ok,
     %RoomsUser{
       id: claims["sub"],
       join_authorizations: join_authz,
       watch_authorizations: watch_authz
     }}
  end

  defp extract_authorization_paths(authorizations, match_prefix) do
    Enum.reduce(authorizations, [], fn authorization, acc ->
      with [^match_prefix, _opts, auth_path] <- String.split(authorization, ":", parts: 3) do
        [auth_path | acc]
      else
        _ ->
          acc
      end
    end)
  end
end
