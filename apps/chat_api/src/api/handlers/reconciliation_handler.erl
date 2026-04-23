-module(reconciliation_handler).
-behaviour(cowboy_handler).

-export([init/2]).

init(Req, State) ->
    GroupId = cowboy_req:binding(group_id, Req),

    Result = reconciliation_service:run(GroupId),
    _ = maybe_record_reconciliation_incident(GroupId, Result),

    chat_api_response:success(Result, Req, State, 200).

maybe_record_reconciliation_incident(GroupId, Result) when is_map(Result) ->
    case maps:get(status, Result, ok) of
        drift_detected ->
            ops_service:record_incident(
                reconciliation_mismatch,
                warning,
                open,
                #{group_id => GroupId, result => Result}
            );
        _ ->
            ok
    end;
maybe_record_reconciliation_incident(_GroupId, _Result) ->
    ok.