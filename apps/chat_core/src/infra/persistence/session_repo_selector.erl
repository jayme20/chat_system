-module(session_repo_selector).

-export([module/0]).

module() ->
    case application:get_env(chat_core, session_repo_backend, amnesia) of
        amnesia -> session_repo_amnesia;
        _ -> session_repo_ets
    end.
