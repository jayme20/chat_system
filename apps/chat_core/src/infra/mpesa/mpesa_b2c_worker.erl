-module(mpesa_b2c_worker).

-behaviour(gen_server).

-export([start_link/0, start_withdrawal/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, #{}}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

start_withdrawal(Request) ->
    ProcessingEvent = chat_event:new(
        withdrawal_processing,
        maps:get(group_id, Request),
        wallet,
        Request
    ),
    event_store:append(ProcessingEvent),
    event_bus:publish(ProcessingEvent),
    case mpesa_b2c_api:send(Request) of
        {ok, _WithdrawalId} ->
            CompletedEvent = chat_event:new(
                withdrawal_completed,
                maps:get(group_id, Request),
                wallet,
                Request
            ),
            event_store:append(CompletedEvent),
            event_bus:publish(CompletedEvent),
            chat_ledger:record_withdrawal(
                maps:get(withdrawal_id, Request),
                maps:get(group_id, Request),
                maps:get(user_id, Request),
                maps:get(amount, Request)
            ),
            {ok, processing};
        {error, Reason} ->
            FailedEvent = chat_event:new(
                withdrawal_failed,
                maps:get(group_id, Request),
                wallet,
                Request#{reason => Reason}
            ),
            event_store:append(FailedEvent),
            event_bus:publish(FailedEvent),
            {error, Reason}
    end.