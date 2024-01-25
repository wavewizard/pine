defmodule Pine.ProcessManagerPoolSupervisor do
  use DynamicSupervisor
  #######
  # API #
  #######

  def start_link({_, _, _} = mfa) do
    DynamicSupervisor.start_link(__MODULE__, mfa, name: __MODULE__)
  end

  #############
  # Callbacks #
  #############

  @impl true
  def init({m, f, a}) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
