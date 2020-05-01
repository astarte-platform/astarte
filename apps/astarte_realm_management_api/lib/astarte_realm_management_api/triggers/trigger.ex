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

defmodule Astarte.RealmManagement.API.Triggers.Trigger do
  use Ecto.Schema
  import Ecto.Changeset
  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.RealmManagement.API.Triggers.{Action, Trigger}

  @derive {Phoenix.Param, key: :name}
  @primary_key false
  embedded_schema do
    field :name, :string
    field :action, Action
    embeds_many :simple_triggers, SimpleTriggerConfig
  end

  @doc false
  def changeset(%Trigger{} = trigger, attrs) do
    trigger
    |> cast(attrs, [:name, :action])
    |> validate_required([:name, :action])
    |> cast_embed(:simple_triggers, required: true)
  end
end
