-module(auth_identity).

-export([
    resolve_user/1
]).



resolve_user(Identity) ->

    case is_phone(Identity) of
        true ->
            user_store:find_by_phone(Identity);

        false ->
            case is_email(Identity) of
                true ->
                    user_store:find_by_email(Identity);

                false ->
                    {error, invalid_identity}
            end
    end.

is_phone(Value) when is_binary(Value) ->
    Phone = binary_to_list(Value),

    case Phone of
        [$+, $2, $5, $4, D1, D2 | Rest] ->
            is_valid_ke_number([D1, D2 | Rest]);

        _ ->
            false
    end;

is_phone(_) ->
    false.


is_valid_ke_number(Number) ->
    case length(Number) of
        9 ->
            case Number of
                [D | _] when D == $7; D == $1 ->
                    lists:all(fun is_digit/1, Number);
                _ ->
                    false
            end;

        _ ->
            false
    end.

%% =====================================================
%% DIGIT CHECK
%% =====================================================

is_digit(C) ->
    C >= $0 andalso C =< $9.

is_email(Value) ->
    binary:match(Value, <<"@">>) =/= nomatch.


