-module(reconciliation_handler).
-behaviour(cowboy_handler).

-export([init/2]).

init(Req, State) ->
    GroupId = cowboy_req:binding(group_id, Req),

    Result = reconciliation_service:run(GroupId),

    chat_api_response:success(Result, Req, State, 200).