defmodule Pine.EventStore.Behaviour do
  @type db :: String.t() | pid() | atom()

  @type category :: String.t() | atom()

  @type stream_id :: String.t()

  @type event_no :: non_neg_integer()

  @type stream :: {category(), stream_id()}

  @opaque event_stream :: Enumerable.t()

  @type event_record :: %{
          event_type: String.t(),
          event_no: non_neg_integer(),
          event_data: map(),
          meta_data: map()
        }

  @callback read_stream_forward(db, stream, start_no, end_no, batch_size) :: event_stream()
            when db: db(),
                 stream: atom(),
                 start_no: non_neg_integer,
                 end_no: non_neg_integer,
                 batch_size: non_neg_integer()

  @callback append(db, stream, event) :: :ok | {:error, String.t()}
            when db: db(), stream: stream(), event: map()

  @callback append(db, stream, events) :: :ok | {:error, String.t()}
            when db: db(), stream: stream, events: list(map)

  @callback get_stream(db, {category, id}) :: list(event_record())
            when category: atom(), id: non_neg_integer()
end
