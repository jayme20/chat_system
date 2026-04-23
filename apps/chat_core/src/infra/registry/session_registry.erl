-module(session_registry).

-export([register/3, revoke/1, lookup/1]).

register(UserId, DeviceId, Pid) ->
    ets:insert(session_table, {UserId, DeviceId, Pid}).

revoke(UserId) ->
    ets:match_delete(session_table, {UserId, '_', '_'}),
    ok.

lookup(UserId) ->
    ets:lookup(session_table, UserId).