-module(chat_leaderboard_projection).
-behaviour(gen_server).

-export([start_link/0, project/1, top/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, #{}}.

handle_call(_Req, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

project(Events) ->
    lists:foldl(fun apply/2, #{}, Events).

apply(Event, State) ->
    case chat_event:type(Event) of

        contribution_received ->
            P = chat_event:payload(Event),
            User = maps:get(user_id, P),
            Amount = maps:get(amount, P),

            maps:update_with(User,
                fun(V) -> V + Amount end,
                Amount,
                State);

        _ ->
            State
    end.

top(State) ->
    lists:sort(fun({_, A}, {_, B}) -> A > B end,
        maps:to_list(State)).