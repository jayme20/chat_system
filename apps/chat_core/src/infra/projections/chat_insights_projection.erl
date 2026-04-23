-module(chat_insights_projection).
-behaviour(gen_server).

-export([start_link/0, project/1, insights/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {
    contributions = 0,
    withdrawals = 0,
    members = #{}
}).

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
    lists:foldl(fun apply/2, #state{}, Events).

apply(Event, State) ->
    case chat_event:type(Event) of

        contribution_received ->
            P = chat_event:payload(Event),
            State#state{
                contributions = State#state.contributions + maps:get(amount, P)
            };

        withdrawal_completed ->
            P = chat_event:payload(Event),
            State#state{
                withdrawals = State#state.withdrawals + maps:get(amount, P)
            };

        member_added ->
            P = chat_event:payload(Event),
            User = maps:get(user_id, P),
            State#state{
                members = maps:put(User, true, State#state.members)
            };

        _ ->
            State
    end.

insights(State) ->
    #{
        total_contributions => State#state.contributions,
        total_withdrawals => State#state.withdrawals,
        active_members => maps:size(State#state.members)
    }.