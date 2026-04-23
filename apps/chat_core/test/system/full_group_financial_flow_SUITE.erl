-module(full_group_financial_flow_SUITE).

-include_lib("common_test/include/ct.hrl").

all() ->
    [full_flow].

full_flow(_Config) ->
    chat_group_service:create_group(
        <<"g1">>,
        <<"Savings">>,
        <<"Welfare fund">>,
        10000,
        public
    ),

    chat_payment:contribute(
        <<"g1">>,
        <<"u1">>,
        2000,
        <<"mpesa_1">>
    ),

    chat_payment:contribute(
        <<"g1">>,
        <<"u2">>,
        3000,
        <<"mpesa_2">>
    ),

    Total = chat_store:group_total(<<"g1">>),

    ?assert(Total >= 5000).