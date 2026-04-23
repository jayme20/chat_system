-module(rate_limiter).
-export([execute/2, init/0]).

-define(MAX_REQUESTS, 100).
-define(WINDOW_SEC, 60).



init() ->
    case ets:info(rate_limit_table) of
        undefined ->
            ets:new(rate_limit_table, [named_table, public, set]),
            ok;
        _ ->
            ok
    end.


execute(Req, Env) ->

    IP = peer_ip(Req),

    case check_limit(IP) of
        ok ->
            {ok, Req, Env};

        {error, rate_limited} ->
            Req2 = chat_api_response:reply(
                429,
                chat_api_response:error_body(rate_limited, <<"rate limit exceeded">>),
                Req
            ),
            {stop, Req2}
    end.



check_limit(Key) ->
    Now = erlang:system_time(second),

    case ets:lookup(rate_limit_table, Key) of
        [] ->
            ets:insert(rate_limit_table, {Key, 1, Now}),
            ok;

        [{Key, Count, Ts}] ->
            case Now - Ts > ?WINDOW_SEC of
                true ->
                    ets:insert(rate_limit_table, {Key, 1, Now}),
                    ok;

                false when Count >= ?MAX_REQUESTS ->
                    {error, rate_limited};

                false ->
                    ets:insert(rate_limit_table, {Key, Count + 1, Ts}),
                    ok
            end
    end.

peer_ip(Req) ->
    {Ip, _Port} = cowboy_req:peer(Req),
    Ip.