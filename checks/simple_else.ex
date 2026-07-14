#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.Credo.Check.Refactor.SimpleElse do
  use Credo.Check,
    id: "AS0001",
    base_priority: :high,
    category: :refactor,
    explanations: [
      check: """
      `with`'s `else` block should match a single case.

      This is fine:

          with {:ok, user} <- fetch_user(id) do
            user
          else
            :error -> :pippo
          end

      This should be refactored, e.g. by extracting a function:

          with {:ok, user} <- fetch_user(id) do
            user
          else
            {:error, :a} -> :pippo
            {:error, :b} -> :paperino
          end

      The reason for this is that `else` blocks matching multiple cases tend
      to group together errors coming from different steps of the `with`,
      hiding where each error actually originates.
      """
    ]

  alias Credo.Code.Block

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    ctx = Context.build(source_file, params, __MODULE__)
    result = Credo.Code.prewalk(source_file, &walk/2, ctx)
    result.issues
  end

  defp walk({:with, meta, _arguments} = ast, ctx) do
    if Block.else_block?(ast) do
      {ast, check_else(ast, meta, ctx)}
    else
      {ast, ctx}
    end
  end

  defp walk(ast, ctx) do
    {ast, ctx}
  end

  defp check_else(ast, meta, ctx) do
    clauses = Block.else_block_for!(ast)

    if length(clauses) > 1 do
      put_issue(ctx, issue_for(ctx, meta))
    else
      ctx
    end
  end

  defp issue_for(ctx, meta) do
    format_issue(
      ctx,
      message:
        "`with`'s `else` block should not contain more than one case",
      trigger: "else",
      line_no: meta[:line]
    )
  end
end
