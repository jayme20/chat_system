-module(group_wallet).

-compile({no_auto_import, [apply/2]}).

-export([
    credit/2,
    debit/2,
    balance/1,
    from_events/1,
    apply_event/2
]).

-record(wallet, {
    group_id,
    balance = 0
}).

%% =========================================================
%% DOMAIN OPERATIONS
%% =========================================================

credit(Wallet, Amount)
    when is_integer(Amount), Amount > 0 ->
    Wallet#wallet{
        balance = Wallet#wallet.balance + Amount
    }.

%% --------------------------------------------------------

debit(Wallet, Amount)
    when is_integer(Amount), Amount > 0,
         Wallet#wallet.balance >= Amount ->
    Wallet#wallet{
        balance = Wallet#wallet.balance - Amount
    };

debit(Wallet, _Amount) ->
    Wallet.  %% safe no-op (or later return error tuple if you prefer strict mode)

%% --------------------------------------------------------

balance(#wallet{balance = B}) ->
    B.

%% =========================================================
%% EVENT SOURCING
%% =========================================================

from_events(Events) ->
    lists:foldl(fun apply_event/2, #wallet{balance = 0}, Events).

%% --------------------------------------------------------

apply_event(Event, Wallet) ->
    case chat_event:type(Event) of

        contribution_received ->
            Amount = amount(Event),
            credit(Wallet, Amount);

        withdrawal_completed ->
            Amount = amount(Event),
            debit(Wallet, Amount);

        fee_charged ->
            Amount = amount(Event),
            debit(Wallet, Amount);

        refund_issued ->
            Amount = amount(Event),
            credit(Wallet, Amount);

        _ ->
            Wallet
    end.

%% =========================================================
%% HELPERS
%% =========================================================

amount(Event) ->
    P = chat_event:payload(Event),
    maps:get(amount, P, 0).