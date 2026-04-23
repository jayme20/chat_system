-module(chat_event_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    {ok, {
        #{strategy => one_for_one,
          intensity => 10,
          period => 10},
        [event_worker_spec()]
    }}.


event_worker_spec() ->
    #{
        id => chat_event_worker,
        start => {chat_event_worker, start_link, []},
        restart => permanent,
        shutdown => 5000,
        type => worker,
        modules => [chat_event_worker]
    }.