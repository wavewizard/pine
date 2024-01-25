defmodule Pine.Projector do
  @behaviour :gen_statem

  @name :pmanager

  @impl true
  def callback_mode do
    :state_functions
  end

  defstruct event_store: nil,
            view: nil,
            name: nil,
            subscriptions: nil,
            last_processed: 0

  def start_link(args, _type) do
    :gen_statem.start_link({:local, args[:name]}, __MODULE__, args, _type)
  end

  def start(args),
    do:
      :gen_statem.start(
        {:local, @name},
        __MODULE__,
        args,
        []
      )

  def stop, do: :gen_statem.stop(@name)

  def ping, do: :gen_statem.call(@name, :state_info)

  # MANDATORY CALL BACKS

  @impl true
  def init(args) do
    state = %{
      name: args[:name],
      last_processed: args[:last_processed],
      event_store: args[:event_store]
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
    IO.puts("booting up")
    IO.inspect(args)
    IO.inspect(state)

    events = state.event_store.read_stream_forward(:all, state.last_processed, 15)

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

  def syncing(:internal, nil, state) do
    next_batch = state.event_store.read_stream_forward(:all, state.last_processed, 15)

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
        next_action = {:next_event, :internal, nil}
        {:keep_state, state, next_action}

      [x] ->
        handle_sync_event(x, state)

        new_state = %{state | last_processed: state.last_processed + 1}
        next_action_data = events |> Stream.drop(1)
        next_action = {:next_event, :internal, next_action_data}

        {:keep_state, new_state, next_action}
    end
  end

  def syncing(event_type, event_content, state) do
    handle_event(event_type, event_content, state)
  end

  def processing(:internal, _event_data, state) do
    IO.puts("yoo I am in processing state")
    {:keep_state, state}
  end

  def processing(event_type, event_content, state) do
    handle_event(event_type, event_content, state)
  end

  defp handle_event(:internal, {:syncing, state, something}) do
    IO.puts("or maybe I am here")
  end

  defp handle_sync_event({{_, event_no}, event} = ev, _state) do
    case event.event_type do
      "PartyAdded" -> IO.puts("#{event_no} Party Added")
      "PartyUpgraded" -> IO.puts("#{event_no} Party Upgraded")
      "PartyPhoneChanged" -> IO.puts("#{event_no} PartyPhoneChanged")
      _ -> IO.puts("#{event_no} Other Event")
    end
  end

  # PRIVATE FUNCTIONS
  defp handle_event({:call, from}, event, data) do
    {:keep_state, data, [{:reply, from, "pong"}]}
  end
end
