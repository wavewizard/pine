defmodule Pine.DSL do
  defmacro defcommand(command_name, args \\ []) do
    quote do
      defmodule __MODULE__.Commands.unquote(command_name) do
        defstruct unquote(args)
      end

      alias __MODULE__.Commands.unquote(command_name)
    end
  end

  defmacro category(category_name) do
    quote do
      def category, do: unquote(category_name)
    end
  end

  defmacro defevent(event_name, args \\ []) do
    quote do
      defmodule __MODULE__.Events.unquote(event_name) do
        defstruct unquote(args)
      end

      alias __MODULE__.Events.unquote(event_name)
    end
  end

  defmacro use_aggregate_id(agg_name) do
    quote do
      defmodule __MODULE__.unquote(agg_name) do
        defstruct id: nil

        @type t :: %__MODULE__{
                id: UUID
              }
        def new() do
          %__MODULE__{id: UUID.uuid4(:hex)}
        end
      end
    end
  end

  defmacro decide(command, state, apply_state, do: code) do
    quote do
      def decide(
            cmd = unquote(command),
            state = unquote(state)
          )
          when state.state == unquote(apply_state) do
        unquote(code)
      end
    end
  end

  def render_event(module) do
    # https://gist.github.com/josevalim/7432084
    quote do
      unquote(to_string(module))
    end
  end

  defmacro put_evolve(module) do
    aggregate_module = Macro.expand(module, __CALLER__)

    events_module =
      Macro.expand(module, __CALLER__)
      |> Module.concat(Events)

    application =
      aggregate_module
      |> Module.split()
      |> Enum.at(0)
      |> (&("Elixir." <> &1)).()
      |> String.to_existing_atom()
      |> Application.get_application()
      |> :application.get_key(:modules)
      |> elem(1)
      |> Enum.filter(fn item ->
        String.starts_with?(to_string(item), to_string(events_module))
      end)

    event_clauses =
      Enum.map(application, fn x ->
        render_event(x)
      end)

    quote bind_quoted: [event_clauses: event_clauses] do
      def evolve(event, state) do
        case event do
          unquote("etest") -> unquote(1)
        end
      end
    end
  end
end
