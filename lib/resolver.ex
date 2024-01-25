defmodule Pine.Resolver do
  alias Pine.Decider

  def resolve(category, id) do
    # Resolve Category Module
  end

  # def resolve(element_id) when is_binary(element_id) do
  #   [category, id] = element_id |> String.split(["-"])

  #   category
  #   |> Map.get(aggregate_map |> String.to_existing_atom)
  #   |> resolve_module()
  #   |> build_decider()

  # end

  def resolve(element_id) when is_struct(element_id) do
    element_id.__struct__
    |> Module.split()
    |> Enum.reverse()
    |> List.pop_at(0)
    |> (fn {x, y} ->
          trimmed = x |> String.trim_trailing("Id")

          [trimmed | y]
          |> Enum.reverse()
          |> Enum.join(".")
        end).()
    |> resolve_module()
    |> build_decider()
  end

  defp resolve_module(moduleName) do
    ("Elixir." <> moduleName)
    |> String.to_existing_atom()
  end

  def build_decider(module) do
    %Decider{
      decide: &module.decide/2,
      evolve: &module.evolve/2,
      initial_state: module.initial_state,
      category: module.category
    }
  end
end
