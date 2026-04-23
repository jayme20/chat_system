-module(session_repo_amnesia).

-behaviour(session_repo_behaviour).

-export([
    create/3,
    find/2,
    revoke_user/1,
    revoke_device/2
]).

create(UserId, DeviceId, Token) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    Key = {UserId, DeviceId},
    CreatedAt = erlang:system_time(second),
    ExpiresAt = CreatedAt + 86400,
    TokenValue = Token,
    Fun = fun() ->
        ok = mnesia:write({sessions, Key, UserId, DeviceId, TokenValue, ExpiresAt, CreatedAt}),
        {ok, Token}
    end,
    tx(Fun).

find(UserId, DeviceId) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    Key = {UserId, DeviceId},
    case mnesia:dirty_read(sessions, Key) of
        [{sessions, _Key, _UserId, _DeviceId, Token, _ExpiresAt, _CreatedAt}] ->
            {ok, Token};
        [] ->
            {error, not_found}
    end.

revoke_user(UserId) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    Rows = mnesia:dirty_index_read(sessions, UserId, user_id),
    lists:foreach(fun({sessions, Key, _U, _D, _H, _E, _C}) ->
        mnesia:dirty_delete(sessions, Key)
    end, Rows),
    ok.

revoke_device(UserId, DeviceId) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    mnesia:dirty_delete(sessions, {UserId, DeviceId}),
    ok.

tx(Fun) ->
    case mnesia:transaction(Fun) of
        {atomic, Result} -> Result;
        {aborted, Reason} -> {error, Reason}
    end.
