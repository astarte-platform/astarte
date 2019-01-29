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
