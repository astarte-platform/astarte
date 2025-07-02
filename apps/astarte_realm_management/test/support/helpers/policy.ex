defmodule Astarte.Helpers.Policy do
  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.Policy.Handler
  alias Astarte.Core.Triggers.Policy.ErrorKeyword
  alias Astarte.Core.Triggers.Policy.ErrorRange

  # TODO: Remove this function when changeset generators are exposed on astarte_generators
  def policy_struct_to_map(%Policy{} = policy_struct) do
    policy_struct
    |> Map.from_struct()
    |> Map.update!(:error_handlers, fn handlers ->
      Enum.map(handlers, fn %Handler{on: on, strategy: strategy} ->
        on_map =
          case on do
            %ErrorKeyword{keyword: keyword} -> %{on: keyword}
            %ErrorRange{error_codes: codes} -> %{on: codes}
          end

        Map.put(on_map, :strategy, strategy)
      end)
    end)
  end
end
