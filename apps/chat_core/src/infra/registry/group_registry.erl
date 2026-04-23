-module(group_registry).

-export([
    start_link/0,
    register/2,
    lookup/1,
    unregister/1
]).

-define(TABLE, group_registry_table).

%% =====================================================
%% STARTUP
%% =====================================================

start_link() ->
    ensure_table(),
    {ok, spawn(fun loop/0)}.

%% =====================================================
%% PUBLIC API
%% =====================================================

register(GroupId, Pid) when is_pid(Pid) ->
    ets:insert(?TABLE, {GroupId, Pid}),
    ok.

lookup(GroupId) ->
    case ets:lookup(?TABLE, GroupId) of
        [{_, Pid}] when is_pid(Pid) ->
            {ok, Pid};
        [] ->
            not_found
    end.

unregister(GroupId) ->
    ets:delete(?TABLE, GroupId),
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