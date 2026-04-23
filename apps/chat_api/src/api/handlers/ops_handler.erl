-module(ops_handler).
-behaviour(cowboy_handler).

-export([init/2]).

init(Req0, State) ->
    Method = cowboy_req:method(Req0),
    Path = cowboy_req:path(Req0),
    case {Method, action(Path)} of
        {<<"GET">>, dashboard} ->
            chat_api_response:success(ops_service:dashboard(), Req0, State, 200);
        {<<"GET">>, incidents} ->
            chat_api_response:success(#{incidents => ops_service:list_incidents()}, Req0, State, 200);
        {<<"POST">>, retry} ->
            JobId = cowboy_req:binding(job_id, Req0),
            case ops_service:manual_retry(JobId) of
                {ok, retried} ->
                    chat_api_response:accepted(#{result => retried, job_id => JobId}, Req0, State);
                {error, not_found} ->
                    chat_api_response:error(not_found, <<"job not found">>, Req0, State, 404)
            end;
        _ ->
            chat_api_response:error(method_not_allowed, <<"method not allowed">>, Req0, State, 405)
    end.

action(Path) ->
    case {has_suffix(Path, <<"/ops/dashboard">>),
          has_suffix(Path, <<"/ops/incidents">>),
          has_segment(Path, <<"/ops/retries/">>)} of
        {true, _, _} -> dashboard;
        {_, true, _} -> incidents;
        {_, _, true} -> retry;
        _ -> unknown
    end.

has_suffix(Bin, Suffix) ->
    BinSize = byte_size(Bin),
    SuffixSize = byte_size(Suffix),
    case BinSize >= SuffixSize of
        true -> binary:part(Bin, BinSize - SuffixSize, SuffixSize) =:= Suffix;
        false -> false
    end.

has_segment(Path, Segment) ->
    case binary:match(Path, Segment) of
        nomatch -> false;
        _ -> true
    end.
