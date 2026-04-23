-module(reconciliation_engine).

-export([
    reconcile_group/1,
    compare_wallet_ledger/1,
    compare_mpesa_ledger/1,
    fix_drift/1
]).

-record(result, {
    group_id,
    status,
    mismatches = [],
    timestamp
}).

%% =========================================================
%% MAIN ENTRY
%% =========================================================

reconcile_group(GroupId) ->

    WalletDiff = compare_wallet_ledger(GroupId),
    MpesaDiff = compare_mpesa_ledger(GroupId),

    Status = case {WalletDiff, MpesaDiff} of
        {[], []} -> ok;
        _ -> drift_detected
    end,

    #result{
        group_id = GroupId,
        status = Status,
        mismatches = WalletDiff ++ MpesaDiff,
        timestamp = erlang:system_time(second)
    }.

%% =========================================================
%% WALLET vs LEDGER
%% =========================================================

compare_wallet_ledger(GroupId) ->

    Wallet = wallet_projection:get(GroupId),
    Ledger = chat_ledger:get_group_entries(GroupId),

    WalletBalance = get_wallet_balance(Wallet),
    LedgerBalance = compute_ledger_balance(Ledger),

    case WalletBalance =:= LedgerBalance of
        true -> [];
        false ->
            [{wallet_ledger_mismatch, #{
                wallet => WalletBalance,
                ledger => LedgerBalance
            }}]
    end.

%% =========================================================
%% MPESA vs LEDGER
%% =========================================================

compare_mpesa_ledger(GroupId) ->

    Mpesa = safe_list(mpesa_sync:get_group_transactions(GroupId)),
    Ledger = safe_list(chat_ledger:get_group_entries(GroupId)),

    MpesaIds = extract_ids(Mpesa),
    LedgerIds = extract_ids(Ledger),

    MissingLedger = MpesaIds -- LedgerIds,
    MissingMpesa = LedgerIds -- MpesaIds,

    case {MissingLedger, MissingMpesa} of
        {[], []} -> [];
        _ ->
            [{mpesa_ledger_mismatch, #{
                missing_in_ledger => MissingLedger,
                missing_in_mpesa => MissingMpesa
            }}]
    end.

%% =========================================================
%% LEDGER BALANCE (SAFE)
%% =========================================================

compute_ledger_balance(Entries) ->
    lists:foldl(fun(E, Acc) ->
        Type = safe_get(type, E),
        Amount = safe_get(amount, E, 0),

        case Type of
            contribution -> Acc + Amount;
            withdrawal -> Acc - Amount;
            fee -> Acc - Amount;
            refund -> Acc + Amount;
            _ -> Acc
        end
    end, 0, Entries).

%% =========================================================
%% HELPERS (SAFE ACCESS LAYER)
%% =========================================================

get_wallet_balance(Wallet) when is_map(Wallet) ->
    maps:get(balance, Wallet, 0);

get_wallet_balance({state, Balance}) ->
    Balance;

get_wallet_balance(_ ) ->
    0.

extract_ids(List) ->
    [safe_get(id, X) || X <- List].

safe_get(Key, Map) ->
    safe_get(Key, Map, undefined).

safe_get(Key, Map, Default) when is_map(Map) ->
    maps:get(Key, Map, Default);

safe_get(_, _, Default) ->
    Default.

safe_list(List) when is_list(List) -> List;
safe_list(_) -> [].

%% =========================================================
%% DRIFT FIX
%% =========================================================

fix_drift(Result) ->
    case Result of

        {wallet_ledger_mismatch, _} ->
            wallet_projection:rebuild(),
            {fixed, wallet_rebuilt};

        {mpesa_ledger_mismatch, _} ->
            {requires_manual_review, mpesa_desync};

        _ ->
            {unknown, Result}
    end.