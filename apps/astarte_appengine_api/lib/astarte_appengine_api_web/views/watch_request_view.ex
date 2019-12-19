#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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

defmodule Astarte.AppEngine.APIWeb.WatchRequestView do
  use Astarte.AppEngine.APIWeb, :view

  def render("watch_request.json", %{watch_request: watch_request}) do
    %{
      name: watch_request.name,
      device_id: watch_request.device_id,
      simple_trigger: watch_request.simple_trigger
    }
  end
end
