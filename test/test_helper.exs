defmodule TestHelper do
  def generate_events(events_nr) when events_nr == 1 do
    events = ["PartyAdded", "PartyNameChanged", "PartyPhoneChanged", "PartyUpgraded"]

    %{
      event_type: events |> Enum.random(),
      event_data: %{prop1: "test"},
      event_no: 1,
      meta_data: %{user: 1}
    }
  end

  def generate_events(events_nr) do
    events = ["PartyAdded", "PartyNameChanged", "PartyPhoneChanged", "PartyUpgraded"]

    for i <- 1..events_nr do
      %{
        event_type: events |> Enum.random(),
        event_data: %{prop1: "test"},
        event_no: i,
        meta_data: %{user: 1}
      }
    end
  end
end

# ExUnit.start()
