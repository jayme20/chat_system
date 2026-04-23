-module(group_handler).
-behaviour(cowboy_handler).

-export([init/2]).

init(Req, State) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req),

    io:format("Body: ~p~n", [Body]),

    Req2 = cowboy_req:reply(
        201,
        #{<<"content-type">> => <<"application/json">>},
        <<"{\"status\":\"created\"}">>,
        Req1
    ),

    {ok, Req2, State}.