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
