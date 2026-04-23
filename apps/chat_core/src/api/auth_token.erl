-module(auth_token).

-export([
    generate/3,
    decode/1,
    secret/2
]).

-define(EXPIRY_SECONDS, 86400). %% 24 hours



generate(UserId, DeviceId, _SecretIgnored) ->

    IssuedAt = erlang:system_time(second),
    Expiry = IssuedAt + ?EXPIRY_SECONDS,

    Payload = #{
        user_id => UserId,
        device_id => DeviceId,
        issued_at => IssuedAt,
        expiry => Expiry
    },

    EncodedPayload = base64:encode_to_string(term_to_binary(Payload)),

    Signature = sign(EncodedPayload, secret(UserId, DeviceId)),

    Token = EncodedPayload ++ "." ++ Signature,

    list_to_binary(Token).



decode(Token) when is_binary(Token) ->
    decode(binary_to_list(Token));

decode(Token) ->
    case string:split(Token, ".", all) of

        [PayloadB64, Signature] ->

            case safe_binary_decode(PayloadB64) of

                {ok, Payload} ->

                    Secret = derive_secret(Payload),

                    case sign(PayloadB64, Secret) of
                        Signature ->
                            validate_expiry(Payload);

                        _ ->
                            error
                    end;

                error ->
                    error
            end;

        _ ->
            error
    end.



sign(Data, Secret) ->
    Crypto = crypto:mac(hmac, sha256, Secret, Data),
    base64:encode_to_string(Crypto).



safe_binary_decode(B64) ->
    try
        {ok, binary_to_term(base64:decode(B64))}
    catch
        _:_ ->
            error
    end.



validate_expiry(#{expiry := Expiry} = Payload) ->
    Now = erlang:system_time(second),

    case Now =< Expiry of
        true ->
            UserId = maps:get(user_id, Payload),
            DeviceId = maps:get(device_id, Payload),
            {ok, UserId, DeviceId, secret(UserId, DeviceId)};
        false -> error
    end.

derive_secret(#{user_id := UserId, device_id := DeviceId}) ->
    secret(UserId, DeviceId).

secret(UserId, DeviceId) ->
    crypto:hash(sha256, term_to_binary({UserId, DeviceId})).