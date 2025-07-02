#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.RealmManagement.APIWeb.RealmConfigView do
  use Astarte.RealmManagement.APIWeb, :view
  alias Astarte.RealmManagement.APIWeb.RealmConfigView

  def render("show.json", %{auth_config: auth_config}) do
    %{
      data: render_one(auth_config, RealmConfigView, "auth_config.json", auth_config: auth_config)
    }
  end

  def render("show.json", %{device_registration_limit: limit}) do
    %{
      data: limit
    }
  end

  def render("show.json", %{datastream_maximum_storage_retention: ttl}) do
    %{
      data: ttl
    }
  end

  def render("auth_config.json", %{auth_config: auth_config}) do
    %{jwt_public_key_pem: auth_config.jwt_public_key_pem}
  end
end
