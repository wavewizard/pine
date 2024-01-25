defmodule Pine.EventBus.Bus do
  @moduledoc """
  Module for responsible recieving notification and publishing events

  """

  def start_link(opts) do
    :gen_event.start_link({:local, opts[:bus_name]})
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, opts},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end
end
