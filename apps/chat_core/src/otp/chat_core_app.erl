-module(chat_core_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_Type, _Args) ->
    init_persistence(),
    chat_core_sup:start_link().

stop(_State) ->
    ok.

init_persistence() ->
    EventBackend = application:get_env(chat_core, event_repo_backend, amnesia),
    UserBackend = application:get_env(chat_core, user_repo_backend, amnesia),
    GroupBackend = application:get_env(chat_core, group_repo_backend, amnesia),
    SessionBackend = application:get_env(chat_core, session_repo_backend, amnesia),
    case EventBackend =:= amnesia
        orelse UserBackend =:= amnesia
        orelse GroupBackend =:= amnesia
        orelse SessionBackend =:= amnesia of
        true ->
            ok = chat_amnesia_bootstrap:ensure_started();
        false ->
            ok
    end.