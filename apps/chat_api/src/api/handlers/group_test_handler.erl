-module(group_test_handler).
-behaviour(cowboy_handler).

-export([init/2]).

init(Req0, State) ->
    Method = cowboy_req:method(Req0),
    GroupId = cowboy_req:binding(group_id, Req0),
    Path = cowboy_req:path(Req0),
    case Method of
        <<"POST">> ->
            handle_post(Path, GroupId, Req0, State);
        _ ->
            chat_api_response:error(method_not_allowed, <<"method not allowed">>, Req0, State, 405)
    end.

handle_post(Path, GroupId, Req0, State) ->
    case user_id_from_token(Req0) of
        undefined ->
            chat_api_response:error(unauthorized, <<"missing bearer token">>, Req0, State, 401);
        ActorId ->
            case decode_body(Req0, State) of
                {error, invalid_json, Req1} ->
                    chat_api_response:error(invalid_json, <<"invalid json">>, Req1, State, 400);
                {ok, Data, Req1} ->
                    dispatch_action(Path, GroupId, ActorId, Data, Req1, State)
            end
    end.

dispatch_action(Path, GroupId, ActorId, Data, Req, State) ->
    case action(Path) of
        announcement ->
            post_announcement(GroupId, ActorId, Data, Req, State);
        contribute ->
            post_contribution(GroupId, ActorId, Data, Req, State);
        withdraw ->
            post_withdrawal(GroupId, ActorId, Data, Req, State);
        unknown ->
            chat_api_response:error(not_found, <<"unknown route">>, Req, State, 404)
    end.

post_announcement(GroupId, ActorId, Data, Req, State) ->
    Message = maps:get(<<"message">>, Data, undefined),
    case Message of
        undefined ->
            chat_api_response:error(validation_error, <<"message required">>, Req, State, 400);
        _ ->
            case chat_store:lookup_group(GroupId) of
                not_found ->
                    chat_api_response:error(not_found, <<"group not found">>, Req, State, 404);
                {ok, GroupState} ->
                    Role = actor_role(GroupState, ActorId),
                    case group_policy:can_announce(Role, GroupState) of
                        true ->
                            Event = chat_event:new(
                                group_announcement_posted,
                                GroupId,
                                chat_group,
                                #{user_id => ActorId, message => Message}
                            ),
                            event_store:append(Event),
                            event_bus:publish(Event),
                            chat_api_response:success(
                                #{result => posted, type => chat_message, message => Message},
                                Req,
                                State,
                                200
                            );
                        false ->
                            chat_api_response:error(forbidden, <<"admin required">>, Req, State, 403)
                    end
            end
    end.

post_contribution(GroupId, ActorId, Data, Req, State) ->
    Amount = maps:get(<<"amount">>, Data, undefined),
    case Amount of
        A when is_integer(A), A > 0 ->
            UserId = maps:get(<<"user_id">>, Data, ActorId),
            Receipt = maps:get(<<"receipt">>, Data, contribution_receipt()),
            respond_payment(
                chat_payment:contribute(GroupId, UserId, A, Receipt),
                <<"contribution processed">>,
                Req,
                State
            );
        _ ->
            chat_api_response:error(validation_error, <<"amount must be positive integer">>, Req, State, 400)
    end.

post_withdrawal(GroupId, ActorId, Data, Req, State) ->
    Amount = maps:get(<<"amount">>, Data, undefined),
    case Amount of
        A when is_integer(A), A > 0 ->
            case chat_store:lookup_group(GroupId) of
                not_found ->
                    chat_api_response:error(not_found, <<"group not found">>, Req, State, 404);
                {ok, GroupState} ->
                    Role = actor_role(GroupState, ActorId),
                    respond_payment(
                        chat_payment:withdraw(GroupId, ActorId, A, Role),
                        <<"withdrawal processing">>,
                        Req,
                        State
                    )
            end;
        _ ->
            chat_api_response:error(validation_error, <<"amount must be positive integer">>, Req, State, 400)
    end.

respond_payment({ok, duplicate}, Message, Req, State) ->
    chat_api_response:success(#{result => duplicate, message => Message}, Req, State, 200);
respond_payment({ok, processed}, Message, Req, State) ->
    chat_api_response:success(#{result => processed, message => Message}, Req, State, 200);
respond_payment({ok, processing}, Message, Req, State) ->
    chat_api_response:accepted(#{result => processing, message => Message}, Req, State);
respond_payment({error, forbidden}, _Message, Req, State) ->
    chat_api_response:error(forbidden, <<"admin/treasurer required">>, Req, State, 403);
respond_payment({error, group_not_found}, _Message, Req, State) ->
    chat_api_response:error(not_found, <<"group not found">>, Req, State, 404);
respond_payment({error, Reason}, _Message, Req, State) ->
    chat_api_response:error(payment_failed, io_lib:format("~p", [Reason]), Req, State, 400).

decode_body(Req0, _State) ->
    case cowboy_req:read_body(Req0) of
        {ok, Body, Req1} ->
            case Body of
                <<>> ->
                    {ok, #{}, Req1};
                _ ->
                    try
                        {ok, jsx:decode(Body, [return_maps]), Req1}
                    catch
                        _:_ ->
                            {error, invalid_json, Req1}
                    end
            end;
        {more, _, Req1} ->
            {error, invalid_json, Req1}
    end.

action(Path) ->
    case {has_suffix(Path, <<"/chat_message/announcement">>),
          has_suffix(Path, <<"/chat_payment/contribute">>),
          has_suffix(Path, <<"/chat_payment/withdraw">>)} of
        {true, _, _} -> announcement;
        {_, true, _} -> contribute;
        {_, _, true} -> withdraw;
        _ -> unknown
    end.

has_suffix(Bin, Suffix) ->
    BinSize = byte_size(Bin),
    SuffixSize = byte_size(Suffix),
    case BinSize >= SuffixSize of
        true ->
            binary:part(Bin, BinSize - SuffixSize, SuffixSize) =:= Suffix;
        false ->
            false
    end.

actor_role(GroupState, ActorId) ->
    Members = maps:get(members, GroupState, #{}),
    maps:get(ActorId, Members, member).

user_id_from_token(Req) ->
    case cowboy_req:header(<<"authorization">>, Req) of
        undefined ->
            undefined;
        <<"Bearer ", Token/binary>> ->
            case auth_token:decode(Token) of
                {ok, UserId, _DeviceId, _Secret} -> UserId;
                _ -> undefined
            end;
        _ ->
            undefined
    end.

contribution_receipt() ->
    list_to_binary(
        io_lib:format("test-c2b-~p-~p", [
            erlang:unique_integer([monotonic, positive]),
            erlang:system_time(millisecond)
        ])
    ).
