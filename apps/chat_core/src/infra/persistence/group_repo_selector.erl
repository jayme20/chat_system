-module(group_repo_selector).

-export([module/0]).

module() ->
    case application:get_env(chat_core, group_repo_backend, amnesia) of
        amnesia -> group_repo_amnesia;
        _ -> group_repo_ets
    end.
