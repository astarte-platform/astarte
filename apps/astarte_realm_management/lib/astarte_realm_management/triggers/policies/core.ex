defmodule Astarte.RealmManagement.Triggers.Policies.Core do
  alias Astarte.RealmManagement.Triggers.Core, as: TriggersCore
  alias Astarte.RealmManagement.Triggers.Queries, as: TriggerQueries
  alias Astarte.RealmManagement.Triggers.Policies.Queries, as: PolicyQueries

  require Logger

  def verify_trigger_policy_not_exists(realm_name, policy_name) do
    with {:ok, exists?} <-
           TriggerQueries.check_trigger_policy_already_present(realm_name, policy_name) do
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

  def delete_trigger_policy(realm_name, policy_name, opts \\ []) do
    _ =
      Logger.info("Going to delete trigger policy #{policy_name}",
        tag: "delete_trigger_policy",
        policy_name: policy_name
      )

    with :ok <- TriggersCore.verify_trigger_policy_exists(realm_name, policy_name),
         {:ok, false} <- check_trigger_policy_has_triggers(realm_name, policy_name) do
      if opts[:async] do
        {:ok, _pid} =
          Task.start(fn -> execute_trigger_policy_deletion(realm_name, policy_name) end)

        :ok
      else
        execute_trigger_policy_deletion(realm_name, policy_name)
      end
    end
  end

  defp check_trigger_policy_has_triggers(realm_name, policy_name) do
    with {:ok, true} <- PolicyQueries.check_policy_has_triggers(realm_name, policy_name) do
      Logger.warning("Trigger policy #{policy_name} is currently being used by triggers",
        tag: "cannot_delete_currently_used_trigger_policy"
      )

      {:error, :cannot_delete_currently_used_trigger_policy}
    end
  end

  def execute_trigger_policy_deletion(realm_name, policy_name) do
    _ =
      Logger.info("Trigger policy deletion started.",
        policy_name: policy_name,
        tag: "delete_trigger_policy_started"
      )

    PolicyQueries.delete_trigger_policy(realm_name, policy_name)
  end
end
