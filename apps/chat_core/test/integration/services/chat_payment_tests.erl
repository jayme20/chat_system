-module(chat_payment_tests).

-include_lib("eunit/include/eunit.hrl").

contribution_flow_test() ->
    test_helper:with_fresh_store(fun() ->

        Result =
            chat_payment:contribute(
                <<"g1">>,
                <<"u1">>,
                1500,
                <<"mpesa_tx_123">>
            ),

        ?assertMatch({ok, processed}, Result),

        Total = chat_store:group_total(<<"g1">>),
        ?assert(Total >= 1500)

    end).