-module(event_repo_amnesia).

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
    ok = chat_amnesia_bootstrap:ensure_started(),
    EventId = chat_event:id(Event),
    Fun = fun() ->
        case mnesia:read(events, EventId, write) of
            [] ->
                ok = mnesia:write({
                    events,
                    EventId,
                    chat_event:aggregate_id(Event),
                    chat_event:type(Event),
                    chat_event:payload(Event),
                    os:system_time(millisecond),
                    0
                }),
                stored;
            [_] ->
                duplicate_ignored
        end
    end,
    case mnesia:transaction(Fun) of
        {atomic, stored} -> {ok, stored};
        {atomic, duplicate_ignored} -> {ok, duplicate_ignored};
        {aborted, Reason} -> {error, Reason}
    end.

exists(EventId) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    case mnesia:dirty_read(events, EventId) of
        [] -> false;
        _ -> true
    end.

get_stream(AggregateId) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    Rows = mnesia:dirty_match_object({events, '_', AggregateId, '_', '_', '_', '_'}),
    [to_event_record(Row) || Row <- Rows].

to_event_record({events, EventId, AggregateId, EventType, Payload, OccurredAt, _Version}) ->
    #event_record{
        event_id = EventId,
        aggregate_id = AggregateId,
        event_type = EventType,
        payload = Payload,
        occurred_at = OccurredAt
    }.
