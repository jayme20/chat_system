-module(group_wallet_tests).

-include_lib("eunit/include/eunit.hrl").
-include("group_wallet.hrl").

credit_wallet_test() ->
    W0 = #wallet{group_id = <<"g1">>, balance = 0},

    W1 = group_wallet:credit(W0, 1000),

    ?assertEqual(1000, group_wallet:balance(W1)).

debit_wallet_test() ->
    W0 = #wallet{group_id = <<"g1">>, balance = 2000},

    W1 = group_wallet:debit(W0, 500),

    ?assertEqual(1500, group_wallet:balance(W1)).