defmodule IeeeTamuPortal.Events do
  @moduledoc """
  The Events context.
  """

  import Ecto.Query, warn: false
  alias IeeeTamuPortal.Repo

  alias IeeeTamuPortal.Events.Event
  alias IeeeTamuPortal.Events.RSVP

  @doc """
  Returns events, filtered and ordered.

  Options:
  - `:after` (DateTime or Date): default `DateTime.utc_now()`; returns events that overlap or occur after this moment.

  Overlap semantics ensure currently-running events are included.
  """
  def list_events(opts \\ []) do
    cutoff =
      case Keyword.get(opts, :after, DateTime.utc_now()) do
        %DateTime{} = dt -> dt
        %Date{} = d -> DateTime.new!(d, ~T[00:00:00], "Etc/UTC")
        other when is_binary(other) -> other |> DateTime.from_iso8601() |> elem(1)
        _ -> DateTime.utc_now()
      end

    query =
      from e in Event,
        where:
          (is_nil(e.dtend) and e.dtstart >= ^cutoff) or
            (not is_nil(e.dtend) and e.dtend >= ^cutoff),
        order_by: [desc: e.dtstart]

    Repo.all(query)
  end

  @doc """
  Gets a single event.

  Raises `Ecto.NoResultsError` if the Event does not exist.

  ## Examples

      iex> get_event!(123)
      %Event{}

      iex> get_event!(456)
      ** (Ecto.NoResultsError)

  """
  def get_event!(uid), do: Repo.get!(Event, uid)

  @doc """
  Creates a event.

  ## Examples

      iex> create_event(%{field: value})
      {:ok, %Event{}}

      iex> create_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_event(attrs \\ %{}) do
    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a event.

  ## Examples

      iex> update_event(event, %{field: new_value})
      {:ok, %Event{}}

      iex> update_event(event, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_event(%Event{} = event, attrs) do
    event
    |> Event.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a event.

  ## Examples

      iex> delete_event(event)
      {:ok, %Event{}}

      iex> delete_event(event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_event(%Event{} = event) do
    Repo.delete(event)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking event changes.

  ## Examples

      iex> change_event(event)
      %Ecto.Changeset{data: %Event{}}

  """
  def change_event(%Event{} = event, attrs \\ %{}) do
    Event.changeset(event, attrs)
  end

  @doc """
  Returns the count of events.

  ## Examples

      iex> count_events()
      5

  """
  def count_events do
    Repo.aggregate(Event, :count, :uid)
  end
end
