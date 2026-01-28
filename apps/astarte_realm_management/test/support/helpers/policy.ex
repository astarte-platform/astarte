defmodule Astarte.Helpers.Policy do
  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.Policy.ErrorKeyword
  alias Astarte.Core.Triggers.Policy.ErrorRange
  alias Astarte.Core.Triggers.Policy.Handler

  # TODO: Remove this function when changeset generators are exposed on astarte_generators
  def policy_struct_to_map(%Policy{} = policy_struct) do
    policy_struct
    |> Map.from_struct()
    |> Map.update!(:error_handlers, &Enum.map(&1, fn handler -> transform_handler(handler) end))
  end

  defp transform_handler(%Handler{on: %ErrorKeyword{keyword: keyword}, strategy: strategy}) do
    %{on: keyword, strategy: strategy}
  end

  defp transform_handler(%Handler{on: %ErrorRange{error_codes: codes}, strategy: strategy}) do
    %{on: codes, strategy: strategy}
  end
end
