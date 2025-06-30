defmodule Astarte.RealmManagement.API.Triggers.Policies.Core do
  alias Astarte.RealmManagement.API.Triggers.Queries

  require Logger

  def verify_trigger_policy_not_exists(realm_name, policy_name) do
    with {:ok, exists?} <- Queries.check_trigger_policy_already_present(realm_name, policy_name) do
      if not exists? do
        :ok
      else
        Logger.warning("Trigger policy #{policy_name} already present",
          tag: "trigger_policy_already_present"
        )

        {:error, :trigger_policy_already_present}
      end
    end
  end

  def validate_trigger_policy(policy_changeset) do
    with {:error, %Ecto.Changeset{} = changeset} <-
           Ecto.Changeset.apply_action(policy_changeset, :insert) do
      _ =
        Logger.warning("Received invalid trigger policy: #{inspect(changeset)}.",
          tag: "invalid_trigger_policy"
        )

      {:error, :invalid_trigger_policy}
    end
  end
end
