-module(user_handler).
-behaviour(cowboy_handler).

-export([init/2]).

%% =====================================================
%% ENTRY
%% =====================================================

init(Req0, State) ->
    Method = cowboy_req:method(Req0),
    dispatch(Method, Req0, State).

%% =====================================================
%% ROUTER
%% =====================================================

dispatch(<<"POST">>, Req, State) ->
    handle_register(Req, State);

dispatch(<<"GET">>, Req, State) ->
    handle_get(Req, State);

dispatch(_, Req, State) ->
    chat_api_response:error(
        method_not_allowed,
        <<"Method not allowed">>,
        Req,
        State,
        405
    ).

%% =====================================================
%% REGISTER USER
%% =====================================================

handle_register(Req0, State) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),

    case decode_json(Body) of
        {ok, Data} ->
            Name  = maps:get(<<"name">>, Data, undefined),
            Email = maps:get(<<"email">>, Data, undefined),
            Phone = maps:get(<<"phone">>, Data, undefined),

            case validate(Name, Email, Phone) of
                ok ->
                    UserId = chat_id:generate(),

                    case user_store:create(UserId, Name, Email, Phone) of
                        {ok, _} ->
                            chat_api_response:created(
                                #{user_id => UserId},
                                Req1,
                                State,
                                201
                            );

                        {error, Reason} ->
                            chat_api_response:error(
                                user_creation_failed,
                                Reason,
                                Req1,
                                State,
                                400
                            )
                    end;

                {error, Reason} ->
                    chat_api_response:error(
                        validation_error,
                        Reason,
                        Req1,
                        State,
                        400
                    )
            end;

        {error, _} ->
            chat_api_response:error(
                invalid_json,
                <<"Invalid JSON body">>,
                Req1,
                State,
                400
            )
    end.

%% =====================================================
%% GET USER
%% =====================================================

handle_get(Req, State) ->
    case cowboy_req:binding(id, Req) of
        undefined ->
            chat_api_response:error(
                missing_user_id,
                <<"Missing user id">>,
                Req,
                State,
                400
            );

        UserId ->
            case user_store:find(UserId) of
                {ok, User} ->
                    chat_api_response:success(
                        sanitize_user(User),
                        Req,
                        State,
                        200
                    );

                {error, not_found} ->
                    chat_api_response:error(
                        not_found,
                        <<"User not found">>,
                        Req,
                        State,
                        404
                    )
            end
    end.

%% =====================================================
%% VALIDATION
%% =====================================================

validate(Name, Email, Phone)
    when Name =/= undefined,
         Email =/= undefined,
         Phone =/= undefined ->
    ok;

validate(_, _, _) ->
    {error, <<"Missing required fields">>}.

%% =====================================================
%% SAFE USER OUTPUT
%% =====================================================

sanitize_user(UserMap) ->
    Timestamp = maps:get(created_at, UserMap),

    ISOTimeList =
        calendar:system_time_to_rfc3339(
            Timestamp,
            [{unit, second}]
        ),

    ISOTime = list_to_binary(ISOTimeList),

    #{
        user_id => maps:get(user_id, UserMap),
        name => maps:get(name, UserMap),
        email => maps:get(email, UserMap),
        phone => maps:get(phone, UserMap),
        status => maps:get(status, UserMap),
        created_at => ISOTime
    }.

%% =====================================================
%% JSON DECODER
%% =====================================================

decode_json(Body) ->
    try
        {ok, jsx:decode(Body, [return_maps])}
    catch
        _:_ ->
            {error, invalid_json}
    end.