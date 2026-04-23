-module(auth_middleware).
-export([execute/2]).

%% Cowboy middleware entry point
execute(Req, Env) ->

    case get_token(Req) of
        undefined ->
            %% allow public routes (customize later)
            {ok, Req, Env};

        Token ->
            case validate_token(Token) of
                {ok, _UserId} ->
                    {ok, Req, Env};

                {error, _Reason} ->
                    Req2 = chat_api_response:reply(
                        401,
                        chat_api_response:error_body(unauthorized, <<"unauthorized">>),
                        Req
                    ),
                    {stop, Req2}
            end
    end.

%% =====================================================
%% Helpers
%% =====================================================

get_token(Req) ->
    case cowboy_req:header(<<"authorization">>, Req) of
        undefined -> undefined;
        <<"Bearer ", Token/binary>> -> Token;
        Token -> Token
    end.

validate_token(_Token) ->
    case auth_token:decode(_Token) of
        {ok, UserId, _DeviceId, _Payload} ->
            {ok, UserId};
        _ ->
            {error, invalid_token}
    end.