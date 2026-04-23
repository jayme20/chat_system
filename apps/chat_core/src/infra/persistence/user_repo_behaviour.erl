-module(user_repo_behaviour).

-callback create(UserId :: binary(), Name :: binary(), Email :: binary(), Phone :: binary()) ->
    {ok, binary()} | {error, term()}.
-callback find(UserId :: binary()) -> {ok, map()} | {error, not_found}.
-callback find_by_email(Email :: binary()) -> {ok, binary()} | {error, not_found}.
-callback find_by_phone(Phone :: binary()) -> {ok, binary()} | {error, not_found}.
-callback update(UserId :: binary(), Changes :: map()) -> {ok, map()} | {error, term()}.
-callback activate(UserId :: binary()) -> {ok, map()} | {error, term()}.
