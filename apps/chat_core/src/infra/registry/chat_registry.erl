-module(chat_registry).

-export([
    register/2,
    lookup/1,
    unregister/1,
    is_alive/1
]).

%% =====================================================
%% REGISTER USER PROCESS (IDEMPOTENT + SAFE)
%% =====================================================
register(UserId, Pid) when is_pid(Pid) ->

    case is_process_alive(Pid) of
        true ->
            ets:insert(chat_registry, {UserId, Pid}),
            {ok, registered};

        false ->
            {error, dead_pid}
    end.

%% =====================================================
%% LOOKUP USER PROCESS
%% =====================================================
lookup(UserId) ->
    case ets:lookup(chat_registry, UserId) of
        [{UserId, Pid}] when is_pid(Pid) ->
            case is_process_alive(Pid) of
                true -> {ok, Pid};
                false ->
                    ets:delete(chat_registry, UserId),
                    error
            end;
        _ ->
            error
    end.

%% =====================================================
%% UNREGISTER USER
%% =====================================================
unregister(UserId) ->
    ets:delete(chat_registry, UserId),
    ok.

%% =====================================================
%% CHECK LIVENESS (UTILITY)
%% =====================================================
is_alive(UserId) ->
    case lookup(UserId) of
        {ok, _Pid} -> true;
        error -> false
    end.