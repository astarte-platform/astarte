#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
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

defmodule AstarteE2EWeb.Router do
  @moduledoc false

  use Plug.Router

  if Mix.env() == :dev do
    forward "/sent_emails", to: Bamboo.SentEmailViewerPlug
  end

  plug AstarteE2EWeb.MetricsPlug

  plug :match
  plug :dispatch

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
