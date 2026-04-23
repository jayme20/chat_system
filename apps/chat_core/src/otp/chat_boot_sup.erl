-module(chat_boot_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        #{
            id => chat_boot_worker,
            start => {chat_boot_worker, start_link, []},
            restart => transient,
            shutdown => 5000,
            type => worker,
            modules => [chat_boot_worker]
        }
    ],
    {ok, {{one_for_one, 3, 60}, Children}}.