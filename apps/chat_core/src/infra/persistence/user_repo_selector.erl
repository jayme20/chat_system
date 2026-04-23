-module(user_repo_selector).

-export([module/0]).

module() ->
    case application:get_env(chat_core, user_repo_backend, amnesia) of
        amnesia -> user_repo_amnesia;
        _ -> user_repo_ets
    end.
