-module(chat_revenue_ledger).
-behaviour(gen_server).

-export([start_link/0, project/1, total_fees/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {
    group_id,
    fees = 0
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
            Amount = maps:get(fee, chat_event:payload(Event), 0),
            State#state{fees = State#state.fees + Amount};

        withdrawal_completed ->
            Amount = maps:get(fee, chat_event:payload(Event), 0),
            State#state{fees = State#state.fees + Amount};

        _ ->
            State
    end.

total_fees(#state{fees = F}) -> F.