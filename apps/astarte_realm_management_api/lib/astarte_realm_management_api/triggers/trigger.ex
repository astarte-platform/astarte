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
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.RealmManagement.API.Triggers.Trigger do
  use Ecto.Schema
  import Ecto.Changeset
  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.RealmManagement.API.Triggers.Trigger

  @derive {Phoenix.Param, key: :name}
  @primary_key false
  embedded_schema do
    field :name, :string
    field :action, :map
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
