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

defmodule Astarte.RealmManagement.APIWeb.Plug.AuthorizePath do
  alias Astarte.RealmManagement.API.Config
  alias Astarte.RealmManagement.APIWeb.Plug.GuardianAuthorizePath

  def init(opts) do
    GuardianAuthorizePath.init(opts)
  end

  def call(conn, opts) do
    unless Config.authentication_disabled?() do
      GuardianAuthorizePath.call(conn, opts)
    else
      conn
    end
  end
end
