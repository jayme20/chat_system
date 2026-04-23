-module(chat_group_tests).

-include_lib("eunit/include/eunit.hrl").
-include("chat_group.hrl").

create_group_emits_event_test() ->
    test_helper:with_fresh_store(fun() ->
        {ok, Event} =
            chat_group:create(
                <<"g1">>,
                <<"Welfare Group">>,
                <<"Savings for members">>,
                10000,
                public
            ),

        ?assertEqual(group_created, chat_event:type(Event)),
        ?assertEqual(<<"g1">>, chat_event:aggregate_id(Event))
    end).

rebuild_from_events_test() ->
    test_helper:with_fresh_store(fun() ->

        E1 = chat_event:new(group_created, <<"g1">>, chat_group, #{
            name => <<"Test">>,
            purpose => <<"Save">>,
            target => 10000,
            visibility => public
        }),

        E2 = chat_event:new(member_added, <<"g1">>, chat_group, #{
            user_id => <<"u1">>
        }),

        State = chat_group:from_events([E1, E2]),
        G = chat_group:state(State),

        ?assertEqual(<<"Test">>, G#group.name),
        ?assert(maps:is_key(<<"u1">>, G#group.members))
    end).