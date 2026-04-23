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

            %% GROUP MESSAGING + PAYMENTS
            {"/v1/groups/:group_id/chat_message/announcement", group_test_handler, []},
            {"/v1/groups/:group_id/chat_payment/contribute", group_test_handler, []},
            {"/v1/groups/:group_id/chat_payment/withdraw", group_test_handler, []},
            {"/v1/groups/:group_id/messages", group_sync_handler, []},
            {"/v1/groups/:group_id/acks", group_sync_handler, []},
            {"/v1/groups/:group_id/statements", finance_handler, []},
            {"/v1/groups/:group_id/receipts/:receipt_id", finance_handler, []},

            %% AUTH
            {"/v1/auth/login", auth_handler, []},
            {"/v1/auth/verify", auth_handler, []},

            %% SESSIONS
            {"/v1/sessions/create", session_handler, []},
            {"/v1/sessions/validate", session_handler, []},
            {"/v1/sync/resume", sync_handler, []},
            {"/v1/ws", realtime_ws_handler, []},

            %% COMPLIANCE
            {"/v1/compliance/kyc/submit", compliance_handler, []},
            {"/v1/compliance/aml/screen", compliance_handler, []},
            {"/v1/compliance/disputes/:group_id", compliance_handler, []},
            {"/v1/compliance/disputes/:id/resolve", compliance_handler, []},
            {"/v1/compliance/audit/export", compliance_handler, []},

            %% OPERATIONS + NOTIFICATIONS
            {"/v1/ops/dashboard", ops_handler, []},
            {"/v1/ops/incidents", ops_handler, []},
            {"/v1/ops/retries/:job_id", ops_handler, []},
            {"/v1/notifications", notifications_handler, []},

            %% RECONCILIATION
            {"/v1/reconcile/:group_id", reconciliation_handler, []}
        ]}
    ]).