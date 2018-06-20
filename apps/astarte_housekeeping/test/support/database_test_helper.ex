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

defmodule Astarte.Housekeeping.DatabaseTestHelper do
  alias CQEx.{Client, Query}

  def realm_cleanup(realm) do
    c = Client.new!()

    delete_from_astarte_statement = """
    DELETE FROM astarte.realms
    WHERE realm_name=:realm_name
    """

    delete_from_astarte_query =
      Query.new()
      |> Query.statement(delete_from_astarte_statement)
      |> Query.put(:realm_name, realm)

    drop_keyspace_query =
      Query.new()
      |> Query.statement("DROP KEYSPACE #{realm}")

    Query.call!(c, delete_from_astarte_query)
    Query.call!(c, drop_keyspace_query)

    :ok
  end
end
