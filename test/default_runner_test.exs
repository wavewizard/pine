defmodule Pine.DefaultRunnerTest do
  alias Pine.DefaultRunner

  use ExUnit.Case, async: true

  defmodule Party do
    require Pine.DSL
    alias Pine.DefaultRunnerTest.Command.{AddParty, UpdatePartyName}
    alias Party.Commands
    alias Party.Events
    import Pine.DSL
    @type state :: :zero | :active | :inactive
    defstruct name: nil, surname: nil, state: nil
    def category, do: "Party"
    def initial_state, do: %__MODULE__{name: "", surname: "", state: :zero}

    defcommand(AddParty, [:name, :surname])
    defcommand(UpdateParty, [:name, :surname])
    defevent(PartyAdded, [:name, :surname])
    defevent(PartyUpdated, [:name, :surname])

    decide cmd = %Commands.AddParty{}, _state = %__MODULE__{}, :zero do
      {:ok, [%Events.PartyAdded{name: cmd.name, surname: cmd.surname}]}
    end

    def evolve(state, event) do
      case event do
        %Events.PartyAdded{} = e ->
          %__MODULE__{name: e.name, surname: e.surname, state: :active}

        %Events.PartyUpdated{} = e ->
          %__MODULE__{name: e.name, surname: e.surname, state: :active}
      end
    end
  end

  test "execute_command should spawn the runner with given parameters" do
    command = %Party.Commands.AddParty{name: "test", surname: "test"}
    # decision = PartyDecider.decide(command, PartyDecider.initial_state())
    # assert {:ok, [%PartyDecider.Events.PartyAdded{name: "test", surname: "test"}]} = decision

    registy = Registry.start_link(keys: :unique, name: PartyManagement.Registry)

    app = PartyManagement
    adapter = Cubes.EventStore
    cmd = %Party.Commands.AddParty{name: "test", surname: "test"}
    agg_module = Party
    agg_id = %{id: "ABCDDDEEFFF"}

    Pine.Runner.DefaultRunner.execute(command, app, adapter, agg_module, agg_id)
    assert 1 = 2
  end
end
