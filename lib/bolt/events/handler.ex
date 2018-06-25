defmodule Bolt.Events.Handler do
  @moduledoc """
  Handles scheduled events persisted to the `events` table.
  Event IDs are mapped to timers internally.
  """

  alias Bolt.Events.Deserializer
  alias Bolt.Repo
  alias Bolt.Schema.Event
  alias Ecto.Changeset
  use GenServer

  ## Client API

  def start_link(options) do
    GenServer.start_link(__MODULE__, :ok, options)
  end

  def create(event_map) do
    changeset = Event.changeset(%Event{}, event_map)

    with true <- event_map.event in Deserializer.valid_events(),
         {:ok, created_event} <- Repo.insert(changeset) do
      GenServer.call(__MODULE__, {:create, created_event})
    else
      false ->
        {:error, "`#{event_map.type}` is not a valid event type"}

      {:error, %Changeset{} = changeset} ->
        {:error, changeset.errors}

      {:error, _reason} = error ->
        error
    end
  end

  def update(event, changes_map) do
    changeset = Event.changeset(event, changes_map)

    with {:ok, _timer} <- GenServer.call(__MODULE__, {:drop_timer, event.id}),
         {:ok, updated_event} <- Repo.update(changeset),
         {:ok, _event} <- GenServer.call(__MODULE__, {:create, event}) do
      {:ok, updated_event}
    else
      {:error, _reason} = error -> error
    end
  end

  ## Server Callbacks

  @impl true
  def init(:ok) do
    alias Bolt.Repo
    alias Bolt.Schema.Event
    import Ecto.Query, only: [from: 2]

    # Boot a timer for stale events
    timers =
      from(event in Event, select: event)
      |> Repo.all()
      |> Enum.map(fn event ->
        {
          event,
          Process.send_after(
            self(),
            {:expired, event},
            max(
              DateTime.diff(event.timestamp, DateTime.utc_now(), :millisecond),
              0
            )
          )
        }
      end)
      |> Map.new(fn {event, timer} -> {event.id, timer} end)

    {:ok, timers}
  end

  @impl true
  def handle_call({:create, event}, _from, timers) do
    timers =
      {event,
       Process.send_after(
         self(),
         {:expired, event},
         max(
           DateTime.diff(event.timestamp, DateTime.utc_now(), :millisecond),
           0
         )
       )}
      |> (fn {event, timer} -> Map.put(timers, event.id, timer) end).()

    {:reply, {:ok, event}, timers}
  end

  @impl true
  def handle_call({:drop_timer, event_id}, _from, timers) do
    with {:ok, timer} <- Map.fetch(timers, event_id),
         left_to_expiry when is_integer(left_to_expiry) <- Process.cancel_timer(timer) do
      {:reply, {:ok, timer}, Map.delete(timers, event_id)}
    else
      :error -> {:reply, {:error, "event is not registered in the event handler"}, timers}
      _error -> {:reply, {:error, "could not cancel the timer properly"}, timers}
    end
  end

  @impl true
  def handle_info({:expired, event}, timers) do
    alias Bolt.Events.Deserializer
    alias Bolt.Repo

    {:ok, func} = Deserializer.deserialize(event)
    func.()
    timers = Map.delete(timers, event)
    {:ok, _deleted_event} = Repo.delete(event)

    {:noreply, timers}
  end
end
