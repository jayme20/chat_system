-module(auth_device).

-export([trust/2, is_trusted/2]).

trust(UserId, DeviceId) ->
    ets:insert(device_table, {{UserId, DeviceId}, trusted}).

is_trusted(UserId, DeviceId) ->
    case ets:lookup(device_table, {UserId, DeviceId}) of
        [{{_, _}, trusted}] -> true;
        _ -> false
    end.