-module(group_policy).

-export([
    can_announce/2,
    can_update_target/2,
    can_withdraw/2,
    can_add_member/2,
    can_remove_member/2,
    can_contribute/2
]).

%% =========================================================
%% ANNOUNCEMENTS
%% =========================================================

can_announce(Role, Group) ->
    group_role:is_admin(Role).

%% =========================================================
%% TARGET UPDATES
%% =========================================================

can_update_target(Role, Group) ->
    group_role:is_admin(Role)
    andalso not threshold_locked(Group).

%% =========================================================
%% WITHDRAWALS (MOST CRITICAL RULE)
%% =========================================================

can_withdraw(Role, Group) ->
    group_role:can_manage_finances(Role)
    andalso not fraud_locked(Group)
    andalso withdrawal_allowed_by_purpose(Group).

%% =========================================================
%% MEMBER MANAGEMENT
%% =========================================================

can_add_member(Role, _Group) ->
    group_role:is_admin(Role).

can_remove_member(Role, _Group) ->
    group_role:is_admin(Role).

%% =========================================================
%% CONTRIBUTIONS (ALWAYS ALLOWED)
%% =========================================================

can_contribute(_, _) ->
    true.

%% =========================================================
%% INTERNAL SAFETY RULES
%% =========================================================

threshold_locked(Group) ->
    case maps:get(threshold_triggered, Group, false) of
        true -> true;
        false -> false
    end.

fraud_locked(Group) ->
    case maps:get(risk_score, Group, 0) of
        Score when Score >= 80 -> true;
        _ -> false
    end.

withdrawal_allowed_by_purpose(Group) ->
    Purpose = maps:get(purpose, Group, undefined),

    case Purpose of
        savings ->
            false; 

        welfare ->
            false;  

        emergency ->
            true;

        investment ->
            true;

        event ->
            true;

        _ ->
            false
    end.