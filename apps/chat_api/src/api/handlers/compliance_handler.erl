-module(compliance_handler).
-behaviour(cowboy_handler).

-export([init/2]).

init(Req0, State) ->
    Method = cowboy_req:method(Req0),
    Path = cowboy_req:path(Req0),
    ActorId = user_id_from_token(Req0),
    case ActorId of
        undefined ->
            chat_api_response:error(unauthorized, <<"missing bearer token">>, Req0, State, 401);
        _ ->
            case {Method, action(Path)} of
                {<<"POST">>, kyc_submit} -> handle_kyc_submit(ActorId, Req0, State);
                {<<"POST">>, aml_screen} -> handle_aml_screen(ActorId, Req0, State);
                {<<"POST">>, dispute_create} -> handle_dispute_create(ActorId, Req0, State);
                {<<"POST">>, dispute_resolve} -> handle_dispute_resolve(ActorId, Req0, State);
                {<<"GET">>, audit_export} -> handle_audit_export(Req0, State);
                _ -> chat_api_response:error(not_found, <<"route not found">>, Req0, State, 404)
            end
    end.

handle_kyc_submit(UserId, Req0, State) ->
    with_json_body(Req0, State, fun(Data, Req1) ->
        Result = compliance_service:submit_kyc(UserId, Data),
        chat_api_response:success(Result, Req1, State, 200)
    end).

handle_aml_screen(UserId, Req0, State) ->
    with_json_body(Req0, State, fun(Data, Req1) ->
        Result = compliance_service:screen_aml(UserId, Data),
        chat_api_response:success(Result, Req1, State, 200)
    end).

handle_dispute_create(UserId, Req0, State) ->
    GroupId = cowboy_req:binding(group_id, Req0),
    with_json_body(Req0, State, fun(Data, Req1) ->
        Result = compliance_service:create_dispute(GroupId, UserId, Data),
        chat_api_response:success(Result, Req1, State, 201)
    end).

handle_dispute_resolve(ActorId, Req0, State) ->
    DisputeId = cowboy_req:binding(id, Req0),
    with_json_body(Req0, State, fun(Data, Req1) ->
        Result = compliance_service:resolve_dispute(DisputeId, ActorId, Data),
        case Result of
            {error, not_found} ->
                chat_api_response:error(not_found, <<"dispute not found">>, Req1, State, 404);
            _ ->
                chat_api_response:success(Result, Req1, State, 200)
        end
    end).

handle_audit_export(Req0, State) ->
    Qs = cowboy_req:parse_qs(Req0),
    Filters = #{
        actor_id => query_bin(Qs, <<"actor_id">>, undefined),
        action => query_atom(Qs, <<"action">>, undefined),
        entity_type => query_atom(Qs, <<"entity_type">>, undefined)
    },
    Logs = audit_log_service:export(Filters),
    chat_api_response:success(#{logs => Logs}, Req0, State, 200).

action(Path) ->
    case {has_suffix(Path, <<"/compliance/kyc/submit">>),
          has_suffix(Path, <<"/compliance/aml/screen">>),
          has_segment(Path, <<"/compliance/disputes/">>),
          has_suffix(Path, <<"/resolve">>),
          has_suffix(Path, <<"/compliance/audit/export">>)} of
        {true, _, _, _, _} -> kyc_submit;
        {_, true, _, _, _} -> aml_screen;
        {_, _, true, false, _} -> dispute_create;
        {_, _, _, true, _} -> dispute_resolve;
        {_, _, _, _, true} -> audit_export;
        _ -> unknown
    end.

with_json_body(Req0, State, Fun) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    case decode_json(Body) of
        {ok, Data} -> Fun(Data, Req1);
        {error, invalid_json} ->
            chat_api_response:error(invalid_json, <<"invalid json">>, Req1, State, 400)
    end.

decode_json(Body) ->
    try
        {ok, jsx:decode(Body, [return_maps])}
    catch
        _:_ -> {error, invalid_json}
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

query_bin(Qs, Key, Default) ->
    case lists:keyfind(Key, 1, Qs) of
        {Key, Value} -> Value;
        false -> Default
    end.

query_atom(Qs, Key, Default) ->
    case query_bin(Qs, Key, undefined) of
        undefined -> Default;
        Bin -> binary_to_atom(Bin, utf8)
    end.

user_id_from_token(Req) ->
    case cowboy_req:header(<<"authorization">>, Req) of
        undefined -> undefined;
        <<"Bearer ", Token/binary>> ->
            case auth_token:decode(Token) of
                {ok, UserId, _DeviceId, _Secret} -> UserId;
                _ -> undefined
            end;
        _ -> undefined
    end.
