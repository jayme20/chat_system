-module(event_repo_selector).

-export([module/0]).

module() ->
    case application:get_env(chat_core, event_repo_backend, amnesia) of
        amnesia -> event_repo_amnesia;
        _ -> event_repo_ets
    end.
