-module(user).

-export([
    new/4,
    update/2,
    verify/1,
    bind_device/2,
    remove_device/2,
    is_verified/1
]).

-record(user, {
    user_id,
    name,
    email,
    phone,
    status = pending,
    devices = [],
    created_at,
    updated_at
}).

new(UserId, Name, Email, Phone) ->
    Now = erlang:system_time(second),

    #user{
        user_id = UserId,
        name = Name,
        email = Email,
        phone = Phone,
        status = pending,
        devices = [],
        created_at = Now,
        updated_at = Now
    }.


update(User, Changes) ->
    User#user{
        name = maps:get(name, Changes, User#user.name),
        phone = maps:get(phone, Changes, User#user.phone),
        email = maps:get(email, Changes, User#user.email),
        updated_at = erlang:system_time(second)
    }.


verify(User) ->
    User#user{
        status = active,
        updated_at = erlang:system_time(second)
    }.


bind_device(User, DeviceId) ->
    Devices = User#user.devices,

    User#user{
        devices = lists:usort([DeviceId | Devices]),
        updated_at = erlang:system_time(second)
    }.


remove_device(User, DeviceId) ->
    Devices = lists:delete(DeviceId, User#user.devices),

    User#user{
        devices = Devices,
        updated_at = erlang:system_time(second)
    }.


is_verified(#user{status = active}) ->
    true;
is_verified(_) ->
    false.