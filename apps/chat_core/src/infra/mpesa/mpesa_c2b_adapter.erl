-module(mpesa_c2b_adapter).

-export([parse/1]).

parse(Req) ->
    #{
        receipt => maps:get("TransID", Req),
        amount => maps:get("Amount", Req),
        phone => maps:get("MSISDN", Req),
        group_id => maps:get("AccountReference", Req)
    }.