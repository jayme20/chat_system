-module(audit_log_service).

-export([record/5, export/1]).

record(ActorId, Action, EntityType, EntityId, Payload) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    LogId = id(<<"audit">>),
    CreatedAt = erlang:system_time(second),
    Fun = fun() ->
        ok = mnesia:write({
            audit_logs,
            LogId,
            ActorId,
            Action,
            EntityType,
            EntityId,
            Payload,
            CreatedAt
        }),
        ok
    end,
    tx(Fun, ok).

export(Filters) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    Rows = mnesia:dirty_match_object({audit_logs, '_', '_', '_', '_', '_', '_', '_'}),
    Filtered = lists:filter(fun(Row) -> matches(Row, Filters) end, Rows),
    [to_map(Row) || Row <- Filtered].

matches({audit_logs, _Id, ActorId, Action, EntityType, _EntityId, _Payload, _At}, Filters) ->
    match_value(actor_id, ActorId, Filters)
    andalso match_value(action, Action, Filters)
    andalso match_value(entity_type, EntityType, Filters).

match_value(Key, Value, Filters) ->
    case maps:get(Key, Filters, undefined) of
        undefined -> true;
        Value -> true;
        _ -> false
    end.

to_map({audit_logs, LogId, ActorId, Action, EntityType, EntityId, Payload, CreatedAt}) ->
    #{
        log_id => LogId,
        actor_id => ActorId,
        action => Action,
        entity_type => EntityType,
        entity_id => EntityId,
        payload => Payload,
        created_at => CreatedAt
    }.

id(Prefix) ->
    PrefixList = case Prefix of
        Bin when is_binary(Bin) -> binary_to_list(Bin);
        List when is_list(List) -> List;
        _ -> "audit"
    end,
    list_to_binary(
        io_lib:format("~s-~p-~p", [
            PrefixList,
            erlang:unique_integer([monotonic, positive]),
            erlang:system_time(millisecond)
        ])
    ).

tx(Fun, Fallback) ->
    case mnesia:transaction(Fun) of
        {atomic, Result} -> Result;
        {aborted, _} -> Fallback
    end.
