-module(notifications_handler).
-behaviour(cowboy_handler).

-export([init/2]).

init(Req0, State) ->
    Method = cowboy_req:method(Req0),
    case Method of
        <<"GET">> ->
            case user_id_from_token(Req0) of
                undefined ->
                    chat_api_response:error(unauthorized, <<"missing bearer token">>, Req0, State, 401);
                UserId ->
                    Data = notification_service:list_user_notifications(UserId),
                    chat_api_response:success(#{notifications => Data}, Req0, State, 200)
            end;
        _ ->
            chat_api_response:error(method_not_allowed, <<"method not allowed">>, Req0, State, 405)
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
