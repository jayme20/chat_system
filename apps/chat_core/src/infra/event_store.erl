-module(event_store).

-export([
    append/1,
    append/2,
    get_stream/1,
    exists/1
]).

append(Event) ->
    append(Event, []).

append(Event, _Opts) ->
    apply(repo(), append, [Event]).


exists(EventId) ->
    apply(repo(), exists, [EventId]).


get_stream(AggregateId) ->
    apply(repo(), get_stream, [AggregateId]).

repo() ->
    event_repo_selector:module().