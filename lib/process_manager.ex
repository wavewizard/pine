defmodule Pine.ProcessRunner do
  @behaviour :gen_statem

  @impl true
  def callback_mode do
    :state_functions
  end

  defstruct event_store: nil,
            driver: nil,
            last_processed: 0,
            posponed_events: []

  def start_link(args, type) do
    IO.inspect(args)
    :gen_statem.start_link({:local, args[:driver].name}, __MODULE__, args, type)
  end

  def switch_to_syncing(pid) do
    :gen_statem.call(pid, :syncing)
  end

  # MANDATORY CALL BACKS

  @impl true
  def init(args) do
    state = %{
      name: args[:driver].name,
      last_processed: args[:last_processed],
      driver: args[:driver],
      event_store: args[:event_store],
      postponed_events: []
    }

    action = {:next_event, :internal, args}
    # {:ok, :booting, args, action}
    {:ok, :booting, state, action}
  end

  @impl true
  def terminate(reason, _state, _data) do
    IO.puts("#{inspect(reason)}")
  end

  # STATE CALL BACKS

  def booting(:internal, args, state) do
    # IO.puts("booting up")
    # IO.inspect(args)
    # IO.inspect(state)

    events =
      state.event_store.read_stream_forward(
        :all,
        state.last_processed,
        nil,
        state.driver.batch_size
      )

    case events |> Enum.count() do
      # nothing to catch move to running state
      0 ->
        {:next_state, :processing, state}

      x when x > 0 ->
        action = {:next_event, :internal, events}
        {:next_state, :syncing, state, action}
    end
  end

  def booting(event_type, event_content, data) do
    handle_event(event_type, event_content, data)
  end

  @doc """
  Synchorinization is done by batches. If we consume all the batch
  we call syncing(:internal, nil, state). This function tries to get
  new stream. If stream has 0 element it changes state to processing
  if stream has more than 0 it call sync(:internal, events, state)
  """
  def resync(:internal, {{{_, event_no}, _} = event_record, events}, state)
      when events == [] do
    IO.puts("Entered Resync starting event: #{state.last_processed} - #{event_no}")

    next_batch =
      state.event_store.read_stream_forward(
        :all,
        state.last_processed,
        event_no,
        state.driver.batch_size
      )
      |> Enum.map(fn x -> x end)

    if next_batch |> Enum.count() > 0 do
      IO.inspect("got things to process")
      next_action = {:next_event, :internal, {event_record, next_batch}}

      {:keep_state, state, next_action}
    else
      # inserting the unprocessed event
      handle_sync_event(event_record, state)
      new_state = update_last_processed_event(state)
      IO.puts("ReSync Completed")
      next_action = {:next_event, :internal, []}
      {:next_state, :processing, new_state, next_action}
    end
  end

  def resync(:internal, {event_record, events}, state)
      when is_list(events) do
    case events do
      [] ->
        # we understand that we consumed the batch request new batch
        next_action = {:next_event, :internal, {event_record, []}}
        {:keep_state, state, next_action}

      [event | rest] ->
        handle_sync_event(event, state)

        new_state = update_last_processed_event(state)
        next_action_data = {event_record, rest}
        next_action = {:next_event, :internal, next_action_data}

        {:keep_state, new_state, next_action}
    end
  end

  def syncing(:internal, nil, state) do
    IO.puts("Entered syncing state")

    next_batch =
      state.event_store.read_stream_forward(
        :all,
        state.last_processed,
        nil,
        state.driver.batch_size
      )

    if next_batch |> Enum.count() > 0 do
      next_action = {:next_event, :internal, next_batch}

      {:keep_state, state, next_action}
    else
      IO.puts("Sync Completed")
      next_action = {:next_event, :internal, []}
      {:next_state, :processing, state, next_action}
    end
  end

  def syncing(:internal, events, state) do
    event_to_process = events |> Stream.take(1) |> Enum.map(fn x -> x end)

    case event_to_process do
      [] ->
        # we understand that we consumed the batch
        next_action = {:next_event, :internal, nil}
        {:keep_state, state, next_action}

      [x] ->
        handle_sync_event(x, state)

        new_state = update_last_processed_event(state)
        next_action_data = events |> Stream.drop(1)
        next_action = {:next_event, :internal, next_action_data}

        {:keep_state, new_state, next_action}
    end
  end

  def syncing(:cast, {{"$all", event_no}, event} = event_record, state) do
    # an event received in syncing must be postponed"
    # TODO TEST THIS
    IO.puts("Receieved an event when syncing event is postponed")
    {:keep_state, event_record, [:postpone]}
  end

  def syncing(event_type, event_content, state) do
    handle_event(event_type, event_content, state)
  end

  def processing(:cast, {{"$all", event_no}, _} = event_record, state) do
    # Check event_no before processing
    # if event_no = last_processed + 1, postpone the event and go to syncing state"
    IO.puts(
      "an event received in processing state event_no: #{inspect(event_no)}, last_seen: #{inspect(state.last_processed)}"
    )

    if event_no == state.last_processed + 1 do
      # handle the event normally
      {:keep_state, state}
    else
      IO.puts("switching to resync state")

      next_event = {:next_event, :internal, {event_record, []}}
      {:next_state, :resync, state, next_event}
    end
  end

  def processing(:internal, _event_data, state) do
    IO.puts("Entered processing state")
    {:keep_state, state}
  end

  def handle_event(:cast, x, state) do
    IO.puts("Wow hold on ")
    {:next_state, x, state}
  end

  # PRIVATE FUNCTIONS

  defp update_last_processed_event(state) do
    %{state | last_processed: state.last_processed + 1}
  end

  defp handle_sync_event({{_, event_no}, event}, state) do
    # serialize the event here
    %{event_type: event_type, event_data: event_data, meta_data: meta} = event
    s_event = struct(String.to_atom(event_type), event_data)

    case state.driver.act_on(s_event) do
      {:repeatable, action, args} ->
        action.(args)

      {:once, action, args} ->
        nil
        # IO.puts("#{event_no} -Not repeatable")
    end
  end

  # defp handle_event({:call, from}, _event, data) do
  #   {:keep_state, data, [{:reply, from, "pong"}]}
  # end
end
