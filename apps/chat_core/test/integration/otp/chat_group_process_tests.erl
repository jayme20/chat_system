-module(chat_group_process_tests).

-include_lib("eunit/include/eunit.hrl").

group_process_state_test() ->
    {ok, Pid} = chat_group:start_link(<<"g1">>),

    State = gen_server:call(Pid, get_state),

    ?assert(State =/= undefined).