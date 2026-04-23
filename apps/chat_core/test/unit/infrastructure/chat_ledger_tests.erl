-module(chat_ledger_tests).

-include_lib("eunit/include/eunit.hrl").

record_contribution_test() ->
    test_helper:setup(),

    TxId = chat_ledger:record_contribution(
        <<"tx1">>,
        <<"g1">>,
        <<"u1">>,
        2000
    ),

    Records = chat_ledger:get_contributions(<<"g1">>),

    ?assert(length(Records) > 0),
    ?assertNotEqual(undefined, TxId),

    test_helper:cleanup().