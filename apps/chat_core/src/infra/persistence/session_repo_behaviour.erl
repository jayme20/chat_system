-module(session_repo_behaviour).

-callback create(UserId :: binary(), DeviceId :: binary(), Token :: binary()) ->
    {ok, binary()} | {error, term()}.
-callback find(UserId :: binary(), DeviceId :: binary()) -> {ok, binary()} | {error, not_found}.
-callback revoke_user(UserId :: binary()) -> ok.
-callback revoke_device(UserId :: binary(), DeviceId :: binary()) -> ok.
