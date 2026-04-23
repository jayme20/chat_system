-module(chat_event).

-export([new/4, new/5, id/1, type/1, payload/1, aggregate_id/1]).

-record(event, {
    event_id,
    event_type,
    aggregate_id,
    aggregate_type,
    occurred_at,
    version = 1,
    payload = #{},
    metadata = #{}
}).

%% STRICT factory (recommended)
new(EventId, Type, AggregateId, AggregateType, Payload) ->
    #event{
        event_id = EventId,
        event_type = Type,
        aggregate_id = AggregateId,
        aggregate_type = AggregateType,
        occurred_at = os:system_time(millisecond),
        payload = Payload
    }.

%% convenience
new(Type, AggregateId, AggregateType, Payload) ->
    new(generate_id(), Type, AggregateId, AggregateType, Payload).

id(#event{event_id = Id}) -> Id.
type(#event{event_type = T}) -> T.
payload(#event{payload = P}) -> P.
aggregate_id(#event{aggregate_id = Id}) -> Id.

generate_id() ->
    list_to_binary(io_lib:format("evt-~p-~p", [
        erlang:unique_integer([monotonic, positive]),
        erlang:system_time(nanosecond)
    ])).