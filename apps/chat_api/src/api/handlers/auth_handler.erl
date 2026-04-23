-module(auth_handler).
-behaviour(cowboy_handler).

-export([init/2]).



init(Req0, State) ->

    Path = cowboy_req:path(Req0),

    case cowboy_req:read_body(Req0) of

        {ok, Body, Req1} ->

            case decode_json(Body) of

                {ok, Data} ->
                    route(Path, Data, Req1, State);

                {error, _} ->
                    chat_api_response:error(
                        invalid_json,
                        <<"invalid json">>,
                        Req1,
                        State,
                        400
                    )
            end;

        {more, _, Req1} ->
            chat_api_response:error(
                payload_too_large,
                <<"payload too large">>,
                Req1,
                State,
                413
            )
    end.



route(<<"/v1/auth/login">>, Data, Req, State) ->
    handle_login(Data, Req, State);

route(<<"/v1/auth/verify">>, Data, Req, State) ->
    handle_verify_otp(Data, Req, State);

route(_, _, Req, State) ->
    chat_api_response:error(
        not_found,
        <<"invalid auth route">>,
        Req,
        State,
        404
    ).



handle_login(Data, Req, State) ->

    Identity = maps:get(<<"identity">>, Data, undefined),
    DeviceId = maps:get(<<"device_id">>, Data, undefined),

    case {Identity, DeviceId} of

        {undefined, _} ->
            chat_api_response:error(validation_error, <<"identity required">>, Req, State, 400);

        {_, undefined} ->
            chat_api_response:error(validation_error, <<"device_id required">>, Req, State, 400);

        {I, D} ->

            case auth_service:login(I, D) of

                {ok, require_otp} ->
                    chat_api_response:accepted(
                        #{
                            status => <<"otp_required">>,
                            message => <<"verify OTP to continue">>
                        },
                        Req,
                        State
                    );

                {ok, Token} ->
                    chat_api_response:success(
                        #{token => Token},
                        Req,
                        State,
                        200
                    );

                {error, Reason} ->
                    chat_api_response:error(
                        auth_failed,
                        Reason,
                        Req,
                        State,
                        401
                    )
            end
    end.



handle_verify_otp(Data, Req, State) ->

    Identity = maps:get(<<"identity">>, Data),
    DeviceId = maps:get(<<"device_id">>, Data),
    OTP      = maps:get(<<"otp">>, Data),

    case auth_service:verify_otp(Identity, DeviceId, OTP) of
        {ok, Token} ->
            chat_api_response:success(
                #{token => Token},
                Req,
                State,
                200
            );

        {error, not_found} ->
            chat_api_response:error(
                auth_failed,
                <<"user not found">>,
                Req,
                State,
                404
            );

        {error, Reason} ->
            chat_api_response:error(
                otp_failed,
                Reason,
                Req,
                State,
                401
            )
    end.

decode_json(Body) ->
    try
        {ok, jsx:decode(Body, [return_maps])}
    catch
        _:_ ->
            {error, invalid_json}
    end.