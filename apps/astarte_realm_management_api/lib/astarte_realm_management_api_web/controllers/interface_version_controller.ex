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
#

defmodule Astarte.RealmManagement.APIWeb.InterfaceVersionController do
  use Astarte.RealmManagement.APIWeb, :controller

  alias Astarte.RealmManagement.API.Interfaces

  action_fallback Astarte.RealmManagement.APIWeb.FallbackController

  def index(conn, %{"realm_name" => realm_name, "id" => id}) do
    with {:ok, interfaces} <- Interfaces.list_interface_major_versions(realm_name, id) do
      render(conn, "index.json", interfaces: interfaces)
    end
  end
end
