-module(dispatcher).
-export([dispatch/0]).

dispatch() ->
    cowboy_router:compile([
        {'_', [

            %% HEALTH
            {"/ping", ping_handler, []},

            %% USERS
            {"/v1/users/register", user_handler, []},
            {"/v1/users/:id", user_handler, []},
            {"/v1/users/:id/verify", user_handler, []},
            {"/v1/users/:id/device", user_handler, []},

            %% GROUPS
            {"/v1/groups", group_handler, []},
            {"/v1/groups/:id", group_handler, []},
            {"/v1/groups/:id/participants", group_member_handler, []},
            {"/v1/groups/:id/participants/leave", group_member_handler, []},
            {"/v1/groups/:id/participants/:phone", group_member_handler, []},
            {"/v1/groups/:id/participants/:phone/promote", group_member_handler, []},
            {"/v1/groups/:id/participants/:phone/demote", group_member_handler, []},

            %% WALLET
            {"/v1/wallets/:group_id/credit", wallet_handler, []},
            {"/v1/wallets/:group_id/debit", wallet_handler, []},

            %% AUTH
            {"/v1/auth/login", auth_handler, []},
            {"/v1/auth/verify", auth_handler, []},

            %% SESSIONS
            {"/v1/sessions/create", session_handler, []},
            {"/v1/sessions/validate", session_handler, []},

            %% RECONCILIATION
            {"/v1/reconcile/:group_id", reconciliation_handler, []}
        ]}
    ]).