-module(crypto_signer).

-export([sign/2, verify/3]).

sign(Payload, Secret) ->
    crypto:mac(hmac, sha256, Secret, term_to_binary(Payload)).

verify(Payload, Signature, Secret) ->
    Signature =:= sign(Payload, Secret).