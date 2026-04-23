-module(session_repo_ets).

-behaviour(session_repo_behaviour).

-export([
    create/3,
    find/2,
    revoke_user/1,
    revoke_device/2
]).

-define(TABLE, session_table).

create(UserId, DeviceId, Token) ->
    ensure(),
    Key = {UserId, DeviceId},
    ets:insert(?TABLE, {Key, Token, erlang:system_time(second)}),
    {ok, Token}.

find(UserId, DeviceId) ->
    ensure(),
    Key = {UserId, DeviceId},
    case ets:lookup(?TABLE, Key) of
        [{Key, Token, _CreatedAt}] -> {ok, Token};
        [] -> {error, not_found}
    end.

revoke_user(UserId) ->
    ensure(),
    MatchSpec = [
        {{'$1', '_', '_'}, [{'==', {element, 1, '$1'}, UserId}], [true]}
    ],
    _ = ets:select_delete(?TABLE, MatchSpec),
    ok.

revoke_device(UserId, DeviceId) ->
    ensure(),
    ets:delete(?TABLE, {UserId, DeviceId}),
    ok.

ensure() ->
    case ets:info(?TABLE) of
        undefined ->
            _ = ets:new(?TABLE, [
                named_table,
                public,
                set,
                {read_concurrency, true},
                {write_concurrency, true}
            ]),
            ok;
        _ ->
            ok
    end.
