defmodule Pine.ProcessManagerServer do
  use GenServer

  def start_link(_args) do
    GenServer.start_link(__MODULE__, _args, name: :test)
  end

  @impl true
  def init(args) do
    # start the ProcManPool
    {:ok, pid} = Pine.ProcessManagerPoolSupervisor.start_link({[], [], []})
    {:ok, []}
  end

  @impl true
  def handle_call(:test, from, state) do
    IO.puts("Ahoy")
    {:reply, "test", state}
  end

  @impl true
  def handle_cast({:add_pm, process_manager, {args, type}}, state) do
    {:ok, child} =
      DynamicSupervisor.start_child(
        Pine.ProcessManagerPoolSupervisor,
        %{
          id: 1,
          start: {process_manager, :start_link, [args, type]},
          type: :worker,
          restart: :permanent,
          shutdown: 500
        }
      )

    IO.puts("The child is #{inspect(child)}")

    {:noreply, state}
  end
end
