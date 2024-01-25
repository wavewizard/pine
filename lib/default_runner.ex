defmodule Pine.Runner.DefaultRunner do
  use GenServer
  require Logger

  defstruct decider: nil,
            application: nil,
            es_adapter: nil,
            aggregate: nil,
            aggregate_id: nil,
            aggregate_state: nil,
            category: nil

  @impl true
  def init(args) do
    {props, opts} =
      args |> Keyword.split([:aggregate_id, :decider, :es_adapter, :aggregate, :application])

    decider = props[:decider]

    runner = %__MODULE__{
      decider: decider,
      application: props[:application],
      aggregate_id: props[:aggregate_id],
      aggregate_state: decider.initial_state,
      es_adapter: props[:es_adapter],
      category: decider.category
    }

    Process.flag(:trap_exit, true)

    {:ok, runner, {:continue, :load_state}}
  end

  def start_link(args, config) do
    GenServer.start_link(__MODULE__, args, name: Keyword.get(args, :name))
  end

  @impl true
  def handle_continue(:load_state, runner) do
    db = runner.es_adapter.get_db(runner.application)
    stream_id = {runner.category, runner.aggregate_id.id}
    Logger.debug("loading events of #{inspect(stream_id)}")

    event_records =
      runner.es_adapter.get_stream(
        db,
        stream_id,
        :event_only
      )

    Logger.debug(" loaded events : #{inspect(event_records)}")

    agg_state =
      event_records
      |> Enum.reduce(runner.aggregate_state, fn {event, _version}, acc ->
        runner.decider.evolve.(acc, event)
      end)

    {:noreply, %{runner | aggregate_state: agg_state}}
  end

  # For safety we should check the last processed event. as it is possible that we can miss some events
  # if :execute command called directly. 
  @impl true
  def handle_call({:execute_command, cmd}, _from, runner) do
    Logger.debug("executing Command #{inspect(cmd)} on #{inspect(runner.aggregate_state)}")

    case runner.decider.decide.(cmd, runner.aggregate_state) do
      {:ok, events} ->
        agg_state =
          List.foldl(events, runner.aggregate, fn e, s ->
            runner.decider.evolve.(s, e)
          end)

        writer = runner.es_adapter.get_writer(runner.application)

        persist_events(
          {runner.category, runner.aggregate_id.id},
          runner.es_adapter,
          writer,
          events
        )

        {:reply, events, %{runner | aggregate_state: agg_state}}

      {:error, reason} ->
        {:reply, reason, runner}
    end
  end

  def handle_call(:get_state, _from, runner) do
    {:reply, runner.aggregate_state, runner}
  end

  @impl true
  def handle_info({:EXIT, _from, reason}, state) do
    Logger.debug("Handled Exit Message")
    {:stop, reason, state}
  end

  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  @impl true
  def terminate(:normal, _state) do
    # Gen server is terminating normally so ok to save the data
    # flush_save_data(state.category, state.aggregate_id, state.events)
    Logger.debug("terminating the gen server")
  end

  @impl true
  def terminate(:shutdown, _state) do
    # gen server is terminating not normally
    Logger.info("Terminating with shutdown")
    :ok
  end

  @impl true
  def terminate(reason, _state) do
    # gen server is terminating not normally
    Logger.info("Terminating with #{inspect(reason)}")
    :ok
  end

  #################################################################################
  # PRIVATE FUNCTIONS                                                             #
  #################################################################################

  defp persist_events(stream_id, adapter, writer, events) do
    adapter.append(writer, stream_id, events)
  end

  ##############################################################################
  #          PUBLIC API
  ##############################################################################

  def get_state(application, adapter, aggregate, aggregate_id, timeout \\ 15_000) do
    registry = Module.concat(application, Registry)
    decider = Pine.Resolver.build_decider(aggregate)
    stream_id = Pine.StreamID.gen(decider.category, aggregate_id) |> Pine.StreamID.to_string()
    es_adapter = adapter
    name = {:via, Registry, {registry, stream_id}}

    case Registry.lookup(registry, stream_id) do
      [] ->
        Logger.debug("spawning a new runner")

        {:ok, pid} =
          start_link(
            [
              decider: decider,
              es_adapter: es_adapter,
              aggregate_id: aggregate_id,
              name: name,
              application: application,
              timeout: timeout
            ],
            []
          )

        GenServer.call(name, :get_state)

      [{pid, _}] ->
        Logger.debug("runner is already running")
        GenServer.call(name, :get_state)
    end
  end

  def execute(command, application, adapter, aggregate, aggregate_id, timeout \\ 15_000) do
    registry = Module.concat(application, Registry)
    decider = Pine.Resolver.build_decider(aggregate)
    stream_id = Pine.StreamID.gen(decider.category, aggregate_id) |> Pine.StreamID.to_string()
    Logger.info("Stream id is = #{stream_id}")

    es_adapter = adapter
    name = {:via, Registry, {registry, stream_id}}

    case Registry.lookup(registry, stream_id) do
      [] ->
        Logger.debug("Spawning a new runner")

        {:ok, pid} =
          start_link(
            [
              decider: decider,
              es_adapter: es_adapter,
              aggregate_id: aggregate_id,
              name: name,
              application: application,
              timeout: timeout
            ],
            []
          )

        GenServer.call(name, {:execute_command, command}, 5000)

      [{pid, _}] ->
        Logger.debug("Runner is already registered, executing command")
        GenServer.call(name, {:execute_command, command})
    end
  end
end
