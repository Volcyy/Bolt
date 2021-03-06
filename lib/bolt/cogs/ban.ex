defmodule Bolt.Cogs.Ban do
  @moduledoc false

  @behaviour Nosedrum.Command

  alias Bolt.{
    ErrorFormatters,
    Events.Handler,
    Helpers,
    Humanizer,
    ModLog,
    Repo,
    Schema.Infraction
  }

  alias Nosedrum.Predicates
  alias Nostrum.Api
  alias Nostrum.Struct.User
  import Ecto.Query, only: [from: 2]
  require Logger

  @impl true
  def usage, do: ["ban <user:snowflake|member> [reason:str]"]

  @impl true
  def description,
    do: """
    Ban the given user with an optional reason.
    An infraction is stored in the infraction database, and can be retrieved later.
    Requires the `BAN_MEMBERS` permission.

    **Examples**:
    ```rs
    // ban Dude without a reason
    ban @Dude#0001

    // the same thing, but with a reason
    ban @Dude#0001 too many cat pictures
    ```
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:ban_members)]

  @spec check_tempban(String.t(), User.id(), Nostrum.Struct.Message.t()) :: :ok
  defp check_tempban(base_string, user_id, msg) do
    tempban_query =
      from(
        infr in Infraction,
        where:
          infr.active and infr.user_id == ^user_id and infr.guild_id == ^msg.guild_id and
            infr.type == "tempban",
        limit: 1,
        select: infr
      )

    case Repo.all(tempban_query) do
      [infr] ->
        {:ok, _updated_infraction} = Handler.update(infr, %{active: false})

        ModLog.emit(
          msg.guild_id,
          "INFRACTION_UPDATE",
          "tempban ##{infr.id} was obsoleted by ban from #{User.full_name(msg.author)}"
        )

        base_string <>
          " - the existing tempban expiring on " <>
          "#{Helpers.datetime_to_human(infr.expires_at)} was set to" <>
          " inactive and I will not automatically unban the user"

      [] ->
        base_string
    end
  end

  @impl true
  def command(msg, [user | reason_list]) do
    response =
      with reason <- Enum.join(reason_list, " "),
           {:ok, user_id, converted_user} <- Helpers.into_id(msg.guild_id, user),
           {:ok, true} <- Helpers.is_above(msg.guild_id, msg.author.id, user_id),
           {:ok} <- Api.create_guild_ban(msg.guild_id, user_id, 7),
           infraction <- %{
             type: "ban",
             guild_id: msg.guild_id,
             user_id: user_id,
             actor_id: msg.author.id,
             reason: if(reason != "", do: reason, else: nil)
           },
           changeset <- Infraction.changeset(%Infraction{}, infraction),
           {:ok, _created_infraction} <- Repo.insert(changeset) do
        user_string = Humanizer.human_user(converted_user || user_id)

        ModLog.emit(
          msg.guild_id,
          "INFRACTION_CREATE",
          "#{Humanizer.human_user(msg.author)} banned #{user_string}" <>
            if(reason != "", do: " with reason `#{reason}`", else: "")
        )

        base_string =
          if(
            reason != "",
            do: "👌 banned #{user_string} with reason `#{reason}`",
            else: "👌 banned #{user_string}"
          )

        check_tempban(base_string, user_id, msg)
      else
        {:ok, false} ->
          "🚫 you need to be above the target user in the role hierarchy"

        error ->
          ErrorFormatters.fmt(msg, error)
      end

    {:ok, _msg} = Api.create_message(msg.channel_id, response)
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `ban <user:snowflake|member> [reason:str...]`"
    {:ok, _msg} = Api.create_message(msg.channel_id, response)
  end
end
