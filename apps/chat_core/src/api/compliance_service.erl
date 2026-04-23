-module(compliance_service).

-export([
    submit_kyc/2,
    screen_aml/2,
    create_dispute/3,
    resolve_dispute/3,
    role_change_audit/4
]).

submit_kyc(UserId, Payload) ->
    write_case(UserId, kyc, submitted, Payload).

screen_aml(UserId, Payload) ->
    RiskScore = maps:get(risk_score, Payload, 0),
    Outcome = case RiskScore >= 80 of
        true -> flagged;
        false -> cleared
    end,
    Result = write_case(UserId, aml, Outcome, Payload),
    _ = audit_log_service:record(UserId, aml_screened, compliance_case, maps:get(case_id, Result), Payload),
    Result.

create_dispute(GroupId, UserId, Payload) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    DisputeId = id(<<"dsp">>),
    CreatedAt = erlang:system_time(second),
    Fun = fun() ->
        ok = mnesia:write({
            disputes,
            DisputeId,
            GroupId,
            UserId,
            open,
            Payload,
            CreatedAt,
            CreatedAt
        }),
        #{dispute_id => DisputeId, status => open}
    end,
    Result = tx(Fun, #{dispute_id => DisputeId, status => open}),
    _ = audit_log_service:record(UserId, dispute_created, dispute, DisputeId, Payload),
    Result.

resolve_dispute(DisputeId, ActorId, ResolutionPayload) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    Fun = fun() ->
        case mnesia:read(disputes, DisputeId, write) of
            [{disputes, DisputeId, GroupId, UserId, _Status, Payload, CreatedAt, _UpdatedAt}] ->
                MergedPayload = maps:merge(
                    ensure_map(Payload),
                    #{resolution => ResolutionPayload}
                ),
                UpdatedAt = erlang:system_time(second),
                ok = mnesia:write({
                    disputes, DisputeId, GroupId, UserId, resolved, MergedPayload, CreatedAt, UpdatedAt
                }),
                #{dispute_id => DisputeId, status => resolved};
            [] ->
                {error, not_found}
        end
    end,
    Result = tx(Fun, {error, not_found}),
    _ = audit_log_service:record(ActorId, dispute_resolved, dispute, DisputeId, ResolutionPayload),
    Result.

role_change_audit(ActorId, GroupId, TargetUserId, NewRole) ->
    audit_log_service:record(
        ActorId,
        role_changed,
        group_member,
        GroupId,
        #{target_user_id => TargetUserId, new_role => NewRole}
    ).

write_case(UserId, Type, Status, Payload) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    CaseId = id(<<"cmp">>),
    CreatedAt = erlang:system_time(second),
    Fun = fun() ->
        ok = mnesia:write({
            compliance_cases,
            CaseId,
            UserId,
            Type,
            Status,
            Payload,
            CreatedAt,
            CreatedAt
        }),
        #{case_id => CaseId, status => Status, type => Type}
    end,
    Result = tx(Fun, #{case_id => CaseId, status => Status, type => Type}),
    _ = audit_log_service:record(UserId, compliance_case_created, compliance_case, CaseId, Payload),
    Result.

ensure_map(M) when is_map(M) -> M;
ensure_map(_) -> #{}.

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
