-module(otp_service).

-export([
    start/0,
    send/2,
    verify/3,
    cleanup/0
]).

-define(TTL, 300).
-define(MAX_ATTEMPTS, 5).
-define(TABLE, otp_table).

%% =====================================================
%% START (ENSURE TABLE EXISTS)
%% =====================================================

start() ->
    case ets:info(?TABLE) of
        undefined ->
            ets:new(?TABLE, [
                named_table,
                public,
                set,
                {read_concurrency, true},
                {write_concurrency, true}
            ]);
        _ ->
            ok
    end.

%% =====================================================
%% OTP GENERATION (FIXED)
%% =====================================================

generate_otp() ->
    <<A:32>> = crypto:strong_rand_bytes(4),
    OtpInt = A rem 1000000,
    list_to_binary(io_lib:format("~6..0B", [OtpInt])).

%% =====================================================
%% SEND OTP
%% =====================================================

send(UserId, DeviceId) ->
    start(),

    Otp = generate_otp(),
    Now = erlang:system_time(second),
    Expiry = Now + ?TTL,

    Key = {UserId, DeviceId},

    ets:insert(?TABLE, {Key, Otp, Expiry, 0}),

    io:format("OTP for ~p => ~s~n", [Key, Otp]),

    {ok, sent}.

%% =====================================================
%% VERIFY OTP (FIXED SAFE COMPARISON)
%% =====================================================

verify(UserId, DeviceId, InputOtp) ->
    start(),

    Key = {UserId, DeviceId},

    InputBin =
        case is_binary(InputOtp) of
            true -> InputOtp;
            false -> list_to_binary(InputOtp)
        end,

    case ets:lookup(?TABLE, Key) of

        [{Key, Otp, Expiry, Attempts}] ->

            Now = erlang:system_time(second),

            case Now > Expiry of
                true ->
                    ets:delete(?TABLE, Key),
                    {error, expired};

                false when Attempts >= ?MAX_ATTEMPTS ->
                    ets:delete(?TABLE, Key),
                    {error, too_many_attempts};

                false ->
                    case Otp =:= InputBin of
                        true ->
                            ets:delete(?TABLE, Key),
                            {ok, verified};

                        false ->
                            ets:insert(?TABLE, {Key, Otp, Expiry, Attempts + 1}),
                            {error, invalid_otp}
                    end
            end;

        [] ->
            {error, not_found}
    end.

%% =====================================================
%% CLEANUP EXPIRED
%% =====================================================

cleanup() ->
    start(),
    Now = erlang:system_time(second),

    All = ets:tab2list(?TABLE),

    [ets:delete(?TABLE, Key)
     || {Key, _Otp, Expiry, _A} <- All,
        Expiry < Now],

    ok.