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
    otp_codes
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
    ]).

create_table(Name, Opts) ->
    case mnesia:create_table(Name, Opts) of
        {atomic, ok} -> ok;
        {aborted, {already_exists, Name}} -> ok
    end.
