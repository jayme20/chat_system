-module(session_handler).
-behaviour(cowboy_handler).

-export([init/2]).



init(Req0, State) ->

    case cowboy_req:read_body(Req0) of

        {ok, Body, Req1} ->

            case decode_json(Body) of
                {ok, Data} ->
                    handle_validate(Data, Req1, State);

                {error, _} ->
                    chat_api_response:error(invalid_json, <<"invalid json">>, Req1, State, 400)
            end;

        {more, _, Req1} ->
            chat_api_response:error(payload_too_large, <<"payload too large">>, Req1, State, 413)
    end.



handle_validate(Data, Req, State) ->

    Token = maps:get(<<"token">>, Data, undefined),

    case Token of
        undefined ->
            chat_api_response:error(validation_error, <<"token required">>, Req, State, 400);

        T ->
            case auth_token:decode(T) of

                {ok, UserId, DeviceId, Secret} ->

                    case session_registry:lookup(UserId, DeviceId) of

                        {ok, Pid} ->
                            Valid = auth_session:is_valid(Pid, Secret),

                            chat_api_response:success(
                                #{
                                    valid => Valid,
                                    user_id => UserId,
                                    device_id => DeviceId
                                },
                                Req,
                                State,
                                200
                            );

                        not_found ->
                            chat_api_response:error(
                                unauthorized,
                                <<"session not found">>,
                                Req,
                                State,
                                401
                            )
                    end;

                error ->
                    chat_api_response:error(unauthorized, <<"invalid token">>, Req, State, 401)
            end
    end.



decode_json(Body) ->
    try
        {ok, jsx:decode(Body, [return_maps])}
    catch
        _:_ ->
            {error, invalid_json}
    end.