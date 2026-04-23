-module(chat_payment).

-export([contribute/4, withdraw/4]).

contribute(GroupId, UserId, Amount, Receipt) ->
    case event_store:exists(Receipt) of
        true ->
            {ok, duplicate};

        false ->
            Fee = chat_fee_engine:calculate_contribution_fee(Amount, #{type => savings}),

            Net = chat_fee_engine:apply_fee(Amount, Fee),

            Event = chat_event:new(
                contribution_received,
                GroupId,
                wallet,
                #{
                    user_id => UserId,
                    amount => Net,
                    fee => Fee,
                    receipt => Receipt
                }
            ),

            event_store:append(Event),
            event_bus:publish(Event),

            chat_ledger:record_contribution(Receipt, GroupId, UserId, Amount),

            {ok, processed}
    end.

withdraw(GroupId, UserId, Amount, Role) ->
    State = chat_store:lookup_group(GroupId),

    case group_policy:can_withdraw(Role, State) of
        true ->
            Fee = chat_fee_engine:calculate_withdrawal_fee(Amount, State),

            Request = #{
                group_id => GroupId,
                user_id => UserId,
                amount => Amount,
                fee => Fee
            },

            mpesa_b2c_worker:start_withdrawal(Request),
            {ok, processing};

        false ->
            {error, forbidden}
    end.