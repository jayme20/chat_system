-module(ops_service).

-export([record_incident/4, dashboard/0, list_incidents/0, manual_retry/1]).

record_incident(Type, Severity, Status, Payload) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    IncidentId = id(<<"ops">>),
    CreatedAt = erlang:system_time(second),
    Fun = fun() ->
        ok = mnesia:write({
            ops_incidents,
            IncidentId,
            Type,
            Severity,
            Status,
            Payload,
            CreatedAt,
            CreatedAt
        }),
        ok
    end,
    tx(Fun, ok),
    IncidentId.

dashboard() ->
    PendingRetries = length(retry_queue:list_pending()),
    DeadLetters = length(retry_queue:list_dead_letter()),
    Incidents = list_incidents(),
    OpenIncidents = [I || I <- Incidents, maps:get(status, I, unknown) =/= resolved],
    #{
        retry_queue_pending => PendingRetries,
        dead_letters => DeadLetters,
        open_incidents => length(OpenIncidents),
        recent_incidents => lists:sublist(Incidents, 20)
    }.

list_incidents() ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    Rows = mnesia:dirty_match_object({ops_incidents, '_', '_', '_', '_', '_', '_', '_'}),
    [to_map(Row) || Row <- Rows].

manual_retry(JobId) ->
    case retry_queue:retry_now(JobId) of
        ok ->
            _ = record_incident(manual_retry, info, resolved, #{job_id => JobId}),
            {ok, retried};
        {error, not_found} = Error ->
            _ = record_incident(manual_retry, warning, open, #{job_id => JobId, error => not_found}),
            Error
    end.

to_map({ops_incidents, IncidentId, Type, Severity, Status, Payload, CreatedAt, UpdatedAt}) ->
    #{
        incident_id => IncidentId,
        type => Type,
        severity => Severity,
        status => Status,
        payload => Payload,
        created_at => CreatedAt,
        updated_at => UpdatedAt
    }.

id(Prefix) ->
    PrefixList = binary_to_list(Prefix),
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
