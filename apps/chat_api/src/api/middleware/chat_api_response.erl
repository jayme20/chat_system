-module(chat_api_response).

-export([
    success/4,
    created/4,
    accepted/3,
    error/5,
    success_body/1,
    error_body/2,
    reply/3
]).



success(Data, Req0, State, Status) ->
    Body = success_body(Data),
    reply(Status, Body, Req0, State).

created(Data, Req0, State, Status) ->
    success(Data, Req0, State, Status).

accepted(Data, Req0, State) ->
    success(Data, Req0, State, 202).



error(Code, Message, Req0, State, Status) ->
    Body = error_body(Code, Message),
    reply(Status, Body, Req0, State).

success_body(Data) ->
    #{
        status => <<"success">>,
        code => <<"ok">>,
        message => <<"request successful">>,
        data => Data
    }.

error_body(Code, Message) ->
    #{
        status => <<"error">>,
        code => atom_to_binary(Code, utf8),
        message => Message
    }.



reply(Status, Body, Req0) ->
    cowboy_req:reply(
        Status,
        #{<<"content-type">> => <<"application/json">>},
        jsx:encode(Body),
        Req0
    ).

reply(Status, Body, Req0, State) ->
    Req1 = reply(Status, Body, Req0),
    {ok, Req1, State}.