-module(auth_service).

-export([
    login/2,
    verify_otp/3,
    issue_session/2,
    logout/1
]).

login(Identity, DeviceId) ->
    case auth_identity:resolve_user(Identity) of
        {ok, UserId} ->
            case auth_device:is_trusted(UserId, DeviceId) of
                true ->
                    issue_session(UserId, DeviceId);

                false ->
                    otp_service:send(UserId, DeviceId),
                        {ok, require_otp}
            end;

        Error ->
            Error
    end.

verify_otp(Identity, DeviceId, OTP) ->
    case auth_identity:resolve_user(Identity) of
        {ok, UserId} ->
            case otp_service:verify(UserId, DeviceId, OTP) of

                {ok, verified} ->
                    Secret = auth_token:secret(UserId, DeviceId),
                    Token = auth_token:generate(UserId, DeviceId, Secret),
                    session_store:create(UserId, DeviceId, Token),
                    {ok, Token};

                Error ->
                    Error
            end;

        Error ->
            Error
    end.

issue_session(UserId, DeviceId) ->
    Secret = crypto:strong_rand_bytes(32),

    {ok, Pid} = auth_session:start(UserId, DeviceId, Secret),

    session_registry:register(UserId, DeviceId, Pid),

    Token = auth_token:generate(UserId, DeviceId, Secret),

    {ok, Token}.

logout(UserId) ->
    session_registry:revoke(UserId),
    ok.