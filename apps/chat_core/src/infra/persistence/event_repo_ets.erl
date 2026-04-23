-module(event_repo_ets).

-behaviour(event_repo_behaviour).

-export([
    append/1,
    exists/1,
    get_stream/1
]).

-record(event_record, {
    event_id,
    aggregate_id,
    event_type,
    payload,
    occurred_at
}).

append(Event) ->
    ensure_table(),
    EventId = chat_event:id(Event),
    case exists(EventId) of
        true ->
            {ok, duplicate_ignored};
        false ->
            Rec = #event_record{
                event_id = EventId,
                aggregate_id = chat_event:aggregate_id(Event),
                event_type = chat_event:type(Event),
                payload = chat_event:payload(Event),
                occurred_at = os:system_time(millisecond)
            },
            ets:insert(event_store_table, {Rec#event_record.event_id, Rec}),
            {ok, stored}
    end.

exists(EventId) ->
    ensure_table(),
    case ets:lookup(event_store_table, EventId) of
        [] -> false;
        _ -> true
    end.

get_stream(AggregateId) ->
    ensure_table(),
    Match = ets:match_object(event_store_table, {'_', #event_record{
        aggregate_id = AggregateId,
        _ = '_'
    }}),
    [E || {_, E} <- Match].

ensure_table() ->
    case ets:info(event_store_table) of
        undefined ->
            _ = ets:new(event_store_table, [
                named_table,
                public,
                set,
                {read_concurrency, true},
                {write_concurrency, true}
            ]),
            ok;
        _ ->
            ok
    end.
