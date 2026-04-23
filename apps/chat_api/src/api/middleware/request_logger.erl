-module(request_logger).
-export([execute/2]).

%% =====================================================
%% ENTRY
%% =====================================================

execute(Req, Env) ->

    Start = erlang:monotonic_time(millisecond),

    Req1 = cowboy_req:register_callback(
        finish,
        fun(_) ->
            log_request(Req, Start),
            ok
        end,
        Req
    ),

    {ok, Req1, Env}.

%% =====================================================
%% LOGGING
%% =====================================================

log_request(Req, Start) ->

    Method = cowboy_req:method(Req),
    Path = cowboy_req:path(Req),

    Duration = erlang:monotonic_time(millisecond) - Start,

    io:format(
        "[REQUEST] ~s ~s took ~p ms~n",
        [Method, Path, Duration]
    ).