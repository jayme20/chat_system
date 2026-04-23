-module(chat_payment).

-export([contribute/4, withdraw/4]).

contribute(GroupId, UserId, Amount, Receipt) ->
    case chat_store:lookup_group(GroupId) of
        not_found ->
            {error, group_not_found};
        {ok, GroupState} ->
            case event_store:exists(Receipt) of
                true ->
                    {ok, duplicate};

                false ->
                    Fee = chat_fee_engine:calculate_contribution_fee(Amount, GroupState),
                    Net = chat_fee_engine:apply_fee(Amount, Fee),

                    Event = chat_event:new(
                        contribution_received,
                        GroupId,
                        wallet,
                        #{
                            user_id => UserId,
                            amount => Net,
                            gross_amount => Amount,
                            fee => Fee,
                            receipt => Receipt
                        }
                    ),

                    event_store:append(Event),
                    event_bus:publish(Event),

                    chat_ledger:record_contribution(Receipt, GroupId, UserId, Net),
                    chat_store:record_contribution(GroupId, UserId, Amount, Net),

                    {ok, processed}
            end
    end.

withdraw(GroupId, UserId, Amount, Role) ->
    case chat_store:lookup_group(GroupId) of
        {ok, GroupState} ->
            case group_policy:can_withdraw(Role, GroupState) of
                true ->
                    Fee = chat_fee_engine:calculate_withdrawal_fee(Amount, GroupState),
                    WithdrawalId = withdrawal_id(),
                    Request = #{
                        withdrawal_id => WithdrawalId,
                        group_id => GroupId,
                        user_id => UserId,
                        amount => Amount,
                        fee => Fee
                    },
                    mpesa_b2c_worker:start_withdrawal(Request);

                false ->
                    {error, forbidden}
            end;
        not_found ->
            {error, group_not_found}
    end.

withdrawal_id() ->
    list_to_binary(
        io_lib:format("wd-~p-~p", [
            erlang:unique_integer([monotonic, positive]),
            erlang:system_time(millisecond)
        ])
    ).