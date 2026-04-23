-module(ledger_persistence).

-export([save/1, all/1]).

save(Entry) ->
    ets:insert(ledger_table, {make_ref(), Entry}),
    ok.

all(GroupId) ->
    ets:match_object(ledger_table, {'_', '$1'}).