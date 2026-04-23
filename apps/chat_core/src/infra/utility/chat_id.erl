-module(chat_id).
-export([generate/0]).

generate() ->
    Bin = crypto:strong_rand_bytes(16),
    <<A:32, B:16, C:16, D:16, E:48>> = Bin,
    iolist_to_binary(
        io_lib:format(
            "~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b",
            [A, B, C, D, E]
        )
    ).