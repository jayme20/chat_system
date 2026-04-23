-module(wallet_projection).
-compile({no_auto_import, [get/1, apply/2]}).

-export([
    init/0,
    apply/2,
    update/1,
    get/1,
    rebuild/1
]).

-record(state, {
    group_id,
    balance = 0,
    total_contributions = 0,
    total_withdrawals = 0,
    pending_withdrawals = 0,
    last_updated = 0
}).



init() ->
    ensure_table(),
    #state{}.


update(Event) ->
    ensure_table(),
    GroupId = chat_event:aggregate_id(Event),
    State = get(GroupId),
    NewState = apply(Event, State),
    persist(NewState),
    NewState.


apply(Event, State) ->
    case chat_event:type(Event) of
        %% Every group starts with a wallet snapshot at zero.
        group_created ->
            State#state{
                group_id = chat_event:aggregate_id(Event),
                last_updated = os:system_time(second)
            };

        contribution_received ->
            Amount = maps:get(amount, chat_event:payload(Event), 0),
            State#state{
                balance = State#state.balance + Amount,
                total_contributions = State#state.total_contributions + Amount,
                last_updated = os:system_time(second)
            };

        withdrawal_processing ->
            Amount = maps:get(amount, chat_event:payload(Event), 0),
            State#state{
                pending_withdrawals = State#state.pending_withdrawals + Amount
            };

        withdrawal_completed ->
            Amount = maps:get(amount, chat_event:payload(Event), 0),
            State#state{
                balance = State#state.balance - Amount,
                total_withdrawals = State#state.total_withdrawals + Amount,
                pending_withdrawals = State#state.pending_withdrawals - Amount
            };

        withdrawal_failed ->
            Amount = maps:get(amount, chat_event:payload(Event), 0),
            State#state{
                pending_withdrawals = State#state.pending_withdrawals - Amount
            };

        fee_charged ->
            Amount = maps:get(amount, chat_event:payload(Event), 0),
            State#state{
                balance = State#state.balance - Amount
            };

        refund_issued ->
            Amount = maps:get(amount, chat_event:payload(Event), 0),
            State#state{
                balance = State#state.balance + Amount
            };

        _ ->
            State
    end.


get(GroupId) ->
    ensure_table(),
    case ets:lookup(wallet_projection_table, GroupId) of
        [{GroupId, State}] ->
            State;
        [] ->
            #state{group_id = GroupId}
    end.


persist(State) ->
    ensure_table(),
    ets:insert(wallet_projection_table, {
        State#state.group_id,
        State
    }).


rebuild(Events) ->
    lists:foldl(fun apply/2, #state{}, Events).

ensure_table() ->
    case ets:info(wallet_projection_table) of
        undefined ->
            _ = ets:new(wallet_projection_table, [
                named_table,
                public,
                set,
                {read_concurrency, true},
                {write_concurrency, true}
            ]),
            ok;
        _ ->
            ok
    end.