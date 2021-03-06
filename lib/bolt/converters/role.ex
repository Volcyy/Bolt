defmodule Bolt.Converters.Role do
  @moduledoc "A converter that converts text to a guild role."

  alias Bolt.Helpers
  alias Nostrum.Api
  alias Nostrum.Cache.GuildCache

  @doc """
  Convert a Discord role mention to an ID.
  This also works if the given string is just the ID.

  ## Examples

    iex> role_mention_to_id("<@&10101010>")
    {:ok, 10101010}
    iex> role_mention_to_id("<@&101010>")
    {:ok, 101010}
    iex> role_mention_to_id("91203")
    {:ok, 91203}
    iex> role_mention_to_id("not valid")
    {:error, "not a valid role ID"}
  """
  @spec role_mention_to_id(String.t()) :: {:ok, pos_integer()} | {:error, String.t()}
  def role_mention_to_id(text) do
    maybe_id =
      text
      |> String.trim_leading("<@&")
      |> String.trim_trailing(">")

    case Integer.parse(maybe_id) do
      {value, ""} -> {:ok, value}
      _ -> {:error, "not a valid role ID"}
    end
  end

  @spec find_by_name(
          [Nostrum.Struct.Guild.Role.t()],
          String.t(),
          boolean()
        ) :: Nostrum.Struct.Role.t() | {:error, String.t()}
  defp find_by_name(roles, name, case_insensitive) do
    result =
      if case_insensitive do
        downcased_name = String.downcase(name)

        Enum.find(
          roles,
          {
            :error,
            "no role matching `#{Helpers.clean_content(name)}` found on this guild (case-insensitive)"
          },
          &(String.downcase(&1.name) == downcased_name)
        )
      else
        Enum.find(
          roles,
          {:error, "no role matching `#{Helpers.clean_content(name)}` found on this guild"},
          &(&1.name == name)
        )
      end

    case result do
      {:error, _reason} = error -> error
      role -> {:ok, role}
    end
  end

  @doc """
  Find a role on the given guild matching `text`.
  The lookup strategy is as follows:
  - Role ID
  - Role mention
  - Role name

  If `ilike` is `true`, then this will perform
  case-insensitive name comparison instead of
  case-sensitive.
  """
  @spec find_role(
          %{Nostrum.Struct.Guild.Role.id() => Nostrum.Struct.Guild.Role.t()},
          String.t(),
          boolean
        ) :: {:ok, Nostrum.Struct.Guild.Role.t()} | {:error, String.t()}
  def find_role(roles, text, ilike) do
    case role_mention_to_id(text) do
      # We have a direct snowflake given. Try to find an exact match.
      {:ok, id} ->
        case Map.get(
               roles,
               id,
               {:error, "No role with ID `#{id}` found on this guild"}
             ) do
          {:error, _reason} = error -> error
          role -> {:ok, role}
        end

      # We do not have a snowflake given, assume it's a name and search through the roles by name.
      {:error, _reason} ->
        roles
        |> Map.values()
        |> find_by_name(text, ilike)
    end
  end

  @doc "Find a role on the given guild ID matching the given text"
  @spec role(Nostrum.Struct.Snowflake.t(), String.t(), boolean) ::
          {:ok, Nowstrum.Struct.Guild.Role.t()} | {:error, String.t()}
  def role(guild_id, text, ilike) do
    case GuildCache.get(guild_id) do
      {:ok, guild} ->
        find_role(guild.roles, text, ilike)

      {:error, _reason} ->
        case Api.get_guild_roles(guild_id) do
          {:ok, roles} ->
            find_role(roles, text, ilike)

          {:error, _reason} ->
            {:error, "This guild is not in the cache, nor could it be fetched from the API."}
        end
    end
  end
end
