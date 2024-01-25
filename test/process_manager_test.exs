defmodule Pine.ProcessRunnerTest do
  alias Pine.ProcessRunner
  use ExUnit.Case, async: true

  defmodule CubesEventStoreMock do
    use Agent
    @behaviour Pine.EventStore.Behaviour

    def start_link() do
      :ets.new(:db, [:ordered_set, :named_table])
      items = generate_items(1, 100) |> Enum.each(fn x -> :ets.insert_new(:db, x) end)
    end

    def select_table() do
      # q =
      #   :ets.select(:db, [
      #     {{{:"$1", :"$2"}, :"$3"}, [{:andalso, {:>, :"$2", 5}, {:<, :"$2", 10}}],
      #      [{{:"$2", :"$3"}}]}
      #   ])
    end

    def add(amount) do
      {_, last_no} = :ets.last(:db)

      # when amount is > last_no it goes down
      generate_items(last_no + 1, last_no + amount)
      |> Enum.each(fn x ->
        :ets.insert_new(:db, x)
      end)
    end

    def read_stream_forward(category, from, nil, batch_size) do
      # I need to select category
      :ets.select(:db, [
        {{{:"$1", :"$2"}, :"$3"}, [{:>, :"$2", from}], [:"$_"]}
      ])
      |> Stream.take(batch_size)
    end

    def read_stream_forward(category, from, end_no, batch_size) do
      # IO.puts("rsf cat: #{category} -- from: #{from} --end: #{end_no} --batch_s: #{batch_size}")

      res =
        :ets.select(:db, [
          {{{:"$1", :"$2"}, :"$3"}, [{:andalso, {:>, :"$2", from}, {:<, :"$2", end_no}}], [:"$_"]}
        ])
        |> Stream.take(batch_size)

      IO.inspect("enum count = #{res |> Enum.count()}")
      res
    end

    def generate_items(starting_no, amount) do
      events = [
        "Elixir.Pine.ProcessRunnerTest.Events.PartyAdded",
        "Elixir.Pine.ProcessRunnerTest.Events.PartyNameChanged",
        "Elixir.Pine.ProcessRunnerTest.Events.PartyNameChanged",
        "Elixir.Pine.ProcessRunnerTest.Events.PartyUpgraded"
      ]

      for i <- starting_no..amount do
        {{<<"$all">>, i},
         %{
           event_type: events |> Enum.random(),
           event_data: %{prop1: "test"},
           event_no: i,
           meta_data: %{user: 1}
         }}
      end
    end
  end

  defmodule Events.PartyAdded do
    defstruct prop1: nil
  end

  defmodule Events.PartyUpgraded do
    defstruct prop1: nil
  end

  defmodule Events.PartyPhoneChanged do
    defstruct prop1: nil
  end

  defmodule Events.PartyNameChanged do
    defstruct prop1: nil
  end

  defmodule TestProcessDriver do
    defstruct name: nil, description: nil

    def name, do: :test_process
    def batch_size, do: 25

    def act_on(event) do
      # serialize event
      args = event
      # an event can produce multiple actions.
      case event do
        %Events.PartyAdded{} -> {:once, &print/1, args}
        %Events.PartyUpgraded{} -> {:once, &print/1, args}
        %Events.PartyNameChanged{} -> {:once, &print/1, args}
        %Events.PartyPhoneChanged{} -> {:once, &print/1, args}
      end
    end

    def print(event) do
      # IO.inspect(event)
    end
  end

  alias Pine.ProcessRunnerTest.CubesEventStoreMock

  setup do
    CubesEventStoreMock.start_link()
    :ok
  end

  # test "It should be started with last_processed event args and db to get the events." do
  #   driver = TestProcessDriver

  #   start_args = [
  #     driver: driver,
  #     last_processed: 0,
  #     event_store: CubesEventStoreMock
  #   ]

  #   {:ok, pid} = Pine.ProcessRunner.start_link(start_args, [])

  #   assert 1 == :sys.get_state(pid)
  # end

  test "read stream forward with end should give the correct amount" do
    # CubesEventStoreMock.start_link()
    x = CubesEventStoreMock.read_stream_forward(:all, 40, 50, 10)
    assert x |> Enum.count() == 9
  end

  test "when I add additional events, the last event no must be correct" do
    {_, current_last} = :ets.last(:db)
    added_amount = 100
    CubesEventStoreMock.add(added_amount)
    expected = current_last + added_amount
    {_, after_adding} = :ets.last(:db)

    assert expected == after_adding
  end

  test "must postpone event when in syncing state" do
    driver = TestProcessDriver

    start_args = [
      driver: driver,
      last_processed: 0,
      event_store: CubesEventStoreMock
    ]

    {:ok, pid} = Pine.ProcessRunner.start_link(start_args, [])
    :timer.sleep(1000)

    CubesEventStoreMock.add(50)
    last_key = :ets.last(:db)
    [last_event] = :ets.lookup(:db, last_key)
    :gen_statem.cast(TestProcessDriver.name(), last_event)

    :timer.sleep(1000)
    assert 1 == 0
  end

  # test "it should try to get the missing events in booting stage" do
  #   start_args = [name: :test_pm, last_processed: 0, event_store: CubesEventStoreMock]
  #   {:ok, pid} = ProcessManager.start_link(start_args, [])
  # end

  # test "it should go to sync state when last_processed < stream last event_no" do
  #   start_args = [name: :test_pm, last_processed: 0, db: CubesMock]
  #   {:ok, pid} = ProcessManager.start_link(start_args, [])
  # end

  # HELPERS #
end
