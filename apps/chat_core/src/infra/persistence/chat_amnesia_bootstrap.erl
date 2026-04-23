-module(chat_amnesia_bootstrap).

-export([
    ensure_started/0,
    ensure_schema/0,
    ensure_tables/0
]).

-define(TABLES, [
    events,
    users,
    groups,
    group_members,
    sessions,
    otp_codes,
    sync_group_seq,
    sync_group_messages,
    sync_group_acks,
    compliance_cases,
    disputes,
    audit_logs,
    notifications,
    ops_incidents
]).

ensure_started() ->
    ok = ensure_schema(),
    case mnesia:start() of
        ok -> ok;
        {error, {already_started, mnesia}} -> ok
    end,
    ensure_tables().

ensure_schema() ->
    Node = node(),
    case mnesia:create_schema([Node]) of
        ok -> ok;
        {error, {Node, {already_exists, _}}} -> ok;
        {error, {already_exists, _}} -> ok;
        {error, {_, {already_exists, _}}} -> ok
    end.

ensure_tables() ->
    lists:foreach(fun ensure_table/1, ?TABLES),
    ok.

ensure_table(events) ->
    create_table(events, [
        {attributes, [event_id, aggregate_id, event_type, payload, occurred_at, version]},
        {disc_copies, [node()]},
        {type, ordered_set}
    ]);
ensure_table(users) ->
    create_table(users, [
        {attributes, [user_id, name, email, phone, status, created_at]},
        {disc_copies, [node()]},
        {type, set},
        {index, [email, phone]}
    ]);
ensure_table(groups) ->
    create_table(groups, [
        {attributes, [group_id, name, purpose, target, visibility, created_by, created_at]},
        {disc_copies, [node()]},
        {type, set}
    ]);
ensure_table(group_members) ->
    create_table(group_members, [
        {attributes, [key, group_id, user_id, role, added_at]},
        {disc_copies, [node()]},
        {type, set},
        {index, [group_id, user_id]}
    ]);
ensure_table(sessions) ->
    create_table(sessions, [
        {attributes, [key, user_id, device_id, token_hash, expires_at, created_at]},
        {disc_copies, [node()]},
        {type, set},
        {index, [user_id]}
    ]);
ensure_table(otp_codes) ->
    create_table(otp_codes, [
        {attributes, [key, user_id, device_id, otp_hash, expires_at, attempts]},
        {disc_copies, [node()]},
        {type, set},
        {index, [user_id]}
    ]);
ensure_table(sync_group_seq) ->
    create_table(sync_group_seq, [
        {attributes, [group_id, seq]},
        {disc_copies, [node()]},
        {type, set}
    ]);
ensure_table(sync_group_messages) ->
    create_table(sync_group_messages, [
        {attributes, [key, group_id, seq, payload, stored_at]},
        {disc_copies, [node()]},
        {type, ordered_set},
        {index, [group_id]}
    ]);
ensure_table(sync_group_acks) ->
    create_table(sync_group_acks, [
        {attributes, [key, group_id, user_id, device_id, ack_seq, updated_at]},
        {disc_copies, [node()]},
        {type, set},
        {index, [group_id, user_id]}
    ]);
ensure_table(compliance_cases) ->
    create_table(compliance_cases, [
        {attributes, [case_id, user_id, type, status, payload, created_at, updated_at]},
        {disc_copies, [node()]},
        {type, ordered_set},
        {index, [user_id, type, status]}
    ]);
ensure_table(disputes) ->
    create_table(disputes, [
        {attributes, [dispute_id, group_id, user_id, status, payload, created_at, updated_at]},
        {disc_copies, [node()]},
        {type, ordered_set},
        {index, [group_id, user_id, status]}
    ]);
ensure_table(audit_logs) ->
    create_table(audit_logs, [
        {attributes, [log_id, actor_id, action, entity_type, entity_id, payload, created_at]},
        {disc_copies, [node()]},
        {type, ordered_set},
        {index, [actor_id, action, entity_type]}
    ]);
ensure_table(notifications) ->
    create_table(notifications, [
        {attributes, [notification_id, user_id, channel, status, payload, created_at, updated_at]},
        {disc_copies, [node()]},
        {type, ordered_set},
        {index, [user_id, channel, status]}
    ]);
ensure_table(ops_incidents) ->
    create_table(ops_incidents, [
        {attributes, [incident_id, type, severity, status, payload, created_at, updated_at]},
        {disc_copies, [node()]},
        {type, ordered_set},
        {index, [type, severity, status]}
    ]).

create_table(Name, Opts) ->
    case mnesia:create_table(Name, Opts) of
        {atomic, ok} -> ok;
        {aborted, {already_exists, Name}} -> ok
    end.
