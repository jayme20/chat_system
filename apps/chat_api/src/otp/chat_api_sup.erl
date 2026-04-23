-module(chat_api_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        #{
            id => chat_api_listener_bridge,
            start => {chat_api_listener_bridge, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [chat_api_listener_bridge]
        }
    ],
    {ok, {{one_for_one, 10, 10}, Children}}.