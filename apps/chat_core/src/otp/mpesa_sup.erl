-module(mpesa_sup).

-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 5
    },

    Children = [
        breaker_worker(),
        c2b_worker(),
        b2c_worker()
    ],

    {ok, {SupFlags, Children}}.

breaker_worker() ->
    #{
        id => mpesa_circuit_breaker,
        start => {mpesa_circuit_breaker, start_link, []},
        restart => permanent,
        type => worker
    }.

c2b_worker() ->
    #{
        id => mpesa_c2b,
        start => {mpesa_c2b_handler, start_link, []},
        restart => permanent,
        type => worker
    }.

b2c_worker() ->
    #{
        id => mpesa_b2c,
        start => {mpesa_b2c_worker, start_link, []},
        restart => permanent,
        type => worker
    }.