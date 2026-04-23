-module(ping_handler).
-export([init/2]).

init(Req0, State) ->
    chat_api_response:success(
        #{message => <<"pong">>},
        Req0,
        State,
        200
    ).