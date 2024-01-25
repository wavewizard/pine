defmodule Pine.ProcManSupervisor do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(args) do
    children = [
      {Pine.ProcessManagerServer, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
