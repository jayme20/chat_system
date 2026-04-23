-module(wallet_handler).
-behaviour(cowboy_handler).

-export([init/2]).

init(Req, State) ->
    Method = cowboy_req:method(Req),
    GroupId = cowboy_req:binding(group_id, Req),

    case cowboy_req:read_body(Req) of
        {ok, Body, Req1} ->
            case decode_json(Body) of
                {error, invalid_json} ->
                    chat_api_response:error(invalid_json, <<"invalid json">>, Req1, State, 400);
                {ok, Data} ->
                    Amount = maps:get(<<"amount">>, Data, undefined),
                    case Amount of
                        undefined ->
                            chat_api_response:error(validation_error, <<"amount required">>, Req1, State, 400);
                        _ ->
                            ActorId = user_id_from_token(Req1),
                            Result =
                                case Method of
                                    <<"POST">> ->
                                        UserId = maps:get(<<"user_id">>, Data, ActorId),
                                        Phone = maps:get(<<"phone">>, Data, <<"254700000000">>),
                                        Receipt = maps:get(<<"receipt">>, Data, simulated_receipt()),
                                        c2b_simulate(GroupId, UserId, Amount, Phone, Receipt);
                                    <<"DELETE">> ->
                                        withdraw_simulate(GroupId, ActorId, Amount);
                                    _ ->
                                        method_not_allowed
                                end,
                            case Result of
                                method_not_allowed ->
                                    chat_api_response:error(
                                        method_not_allowed,
                                        <<"method not allowed">>,
                                        Req1,
                                        State,
                                        405
                                    );
                                {error, unauthorized} ->
                                    chat_api_response:error(
                                        unauthorized,
                                        <<"missing bearer token">>,
                                        Req1,
                                        State,
                                        401
                                    );
                                {error, user_id_required} ->
                                    chat_api_response:error(
                                        validation_error,
                                        <<"user_id required for contribution simulation">>,
                                        Req1,
                                        State,
                                        400
                                    );
                                {error, forbidden} ->
                                    chat_api_response:error(
                                        forbidden,
                                        <<"only admin/treasurer can withdraw">>,
                                        Req1,
                                        State,
                                        403
                                    );
                                {error, group_not_found} ->
                                    chat_api_response:error(
                                        not_found,
                                        <<"group not found">>,
                                        Req1,
                                        State,
                                        404
                                    );
                                {error, Reason} ->
                                    chat_api_response:error(
                                        payment_failed,
                                        io_lib:format("~p", [Reason]),
                                        Req1,
                                        State,
                                        400
                                    );
                                _ ->
                                    chat_api_response:success(
                                        #{result => Result},
                                        Req1,
                                        State,
                                        200
                                    )
                            end
                    end
            end;
        {more, _, Req1} ->
            chat_api_response:error(payload_too_large, <<"payload too large">>, Req1, State, 413)
    end.

decode_json(Body) ->
    try
        {ok, jsx:decode(Body, [return_maps])}
    catch
        _:_ ->
            {error, invalid_json}
    end.

c2b_simulate(_GroupId, undefined, _Amount, _Phone, _Receipt) ->
    {error, user_id_required};
c2b_simulate(GroupId, UserId, Amount, _Phone, Receipt) ->
    chat_payment:contribute(GroupId, UserId, Amount, Receipt).

withdraw_simulate(_GroupId, undefined, _Amount) ->
    {error, unauthorized};
withdraw_simulate(GroupId, ActorId, Amount) ->
    Role = actor_role(GroupId, ActorId),
    chat_payment:withdraw(GroupId, ActorId, Amount, Role).

actor_role(GroupId, ActorId) ->
    case chat_store:lookup_group(GroupId) of
        {ok, Snapshot} ->
            Members = maps:get(members, Snapshot, #{}),
            maps:get(ActorId, Members, member);
        _ ->
            member
    end.

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

simulated_receipt() ->
    list_to_binary(
        io_lib:format("sim-c2b-~p-~p", [
            erlang:unique_integer([monotonic, positive]),
            erlang:system_time(millisecond)
        ])
    ).