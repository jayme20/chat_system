-module(chat_runtime_config).

-export([load/0, get/1, session_ttl_seconds/0]).

-define(KEY, ?MODULE).

load() ->
    Config = #{
        session_ttl_seconds => 86400,
        mpesa_breaker_fail_threshold => 3,
        mpesa_breaker_cooldown_ms => 10000
    },
    persistent_term:put(?KEY, Config),
    ok.

get(Key) ->
    Config = persistent_term:get(?KEY, #{}),
    maps:get(Key, Config, undefined).

session_ttl_seconds() ->
    ?MODULE:get(session_ttl_seconds).
