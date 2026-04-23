-module(user_registry).

-export([
    start_link/0,
    register/2,
    lookup/1,
    unregister/1
]).

-define(TABLE, user_registry_table).

%% =====================================================
%% STARTUP
%% =====================================================

start_link() ->
    ensure_table(),
    {ok, spawn(fun loop/0)}.

%% =====================================================
%% PUBLIC API
%% =====================================================

register(UserId, Pid) when is_pid(Pid) ->
    ensure_table(),
    ets:insert(?TABLE, {UserId, Pid}),
    ok.

lookup(UserId) ->
    case ets:lookup(?TABLE, UserId) of
        [{_, Pid}] when is_pid(Pid) ->
            {ok, Pid};
        [] ->
            not_found
    end.

unregister(UserId) ->
    ets:delete(?TABLE, UserId),
    ok.

%% =====================================================
%% INTERNAL
%% =====================================================

ensure_table() ->
    case ets:info(?TABLE) of
        undefined ->
            ets:new(?TABLE, [
                named_table,
                public,
                set,
                {read_concurrency, true},
                {write_concurrency, true}
            ]);
        _ ->
            ok
    end.

loop() ->
    receive
        _ -> loop()
    end.