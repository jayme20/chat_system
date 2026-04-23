-module(group_policy_tests).

-include_lib("eunit/include/eunit.hrl").

admin_can_add_member_test() ->
    Role = admin,
    Group = #{},

    ?assert(group_policy:can_add_member(Role, Group)).

member_cannot_update_target_test() ->
    Role = member,
    Group = #{},

    ?assertNot(group_policy:can_update_target(Role, Group)).