#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Cases.Trigger do
  use ExUnit.CaseTemplate
  use Mimic

  using opts do
    triggers = Keyword.fetch!(opts, :triggers)

    quote do
      @moduletag triggers: unquote(triggers)

      import Astarte.Helpers.Trigger
    end
  end

  alias Astarte.Helpers.Trigger

  setup_all context do
    %{realm_name: realm_name, triggers: triggers} = context

    Enum.each(triggers, &Trigger.install_trigger(realm_name, &1))
  end
end
