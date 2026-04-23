-module(mpesa_b2c_api).

-export([send/1]).

send(Request) ->
    mpesa_circuit_breaker:execute(
        fun() ->
            timer:sleep(100),
            {ok, maps:get(withdrawal_id, Request)}
        end
    ).