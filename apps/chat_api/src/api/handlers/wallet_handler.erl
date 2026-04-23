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
                            Result =
                                case Method of
                                    <<"POST">> ->
                                        wallet_service:credit(GroupId, Amount);
                                    <<"DELETE">> ->
                                        wallet_service:debit(GroupId, Amount);
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