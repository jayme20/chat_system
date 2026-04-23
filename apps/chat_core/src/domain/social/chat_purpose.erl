-module(chat_purpose).

-export([
    create/1,
    type/1,
    rules/1,
    is_financial_sensitive/1,
    max_withdrawal_limit/1,
    max_contribution_limit/1,
    allows_early_withdrawal/1,
    fraud_sensitivity/1
]).

-record(purpose, {
    type,
    rules = #{}
}).

%% =========================================================
%% PURPOSE CREATION
%% =========================================================

create(Type) ->
    #purpose{
        type = normalize(Type),
        rules = default_rules(normalize(Type))
    }.

%% =========================================================
%% TYPE ACCESS
%% =========================================================

type(#purpose{type = Type}) ->
    Type.

%% =========================================================
%% RULES ACCESS
%% =========================================================

rules(#purpose{rules = R}) ->
    R.

%% =========================================================
%% NORMALIZATION
%% =========================================================

normalize(Type) when is_atom(Type) ->
    Type;
normalize(Type) when is_binary(Type) ->
    list_to_atom(string:lowercase(binary_to_list(Type)));
normalize(Type) ->
    Type.

%% =========================================================
%% DEFAULT PURPOSE BEHAVIOR RULES
%% =========================================================

default_rules(welfare) ->
    #{
        max_withdrawal => 0,          %% locked funds unless admin override
        early_withdrawal => false,
        fraud_sensitivity => high,
        contribution_limit => 100000
    };

default_rules(savings) ->
    #{
        max_withdrawal => 0,
        early_withdrawal => false,
        fraud_sensitivity => high,
        contribution_limit => 500000
    };

default_rules(investment) ->
    #{
        max_withdrawal => 200000,
        early_withdrawal => true,
        fraud_sensitivity => medium,
        contribution_limit => 1000000
    };

default_rules(event) ->
    #{
        max_withdrawal => 50000,
        early_withdrawal => true,
        fraud_sensitivity => medium,
        contribution_limit => 200000
    };

default_rules(emergency) ->
    #{
        max_withdrawal => 1000000,
        early_withdrawal => true,
        fraud_sensitivity => low,
        contribution_limit => 1000000
    };

default_rules(_) ->
    #{
        max_withdrawal => 0,
        early_withdrawal => false,
        fraud_sensitivity => high,
        contribution_limit => 100000
    }.

%% =========================================================
%% FINANCIAL BEHAVIOR QUERIES
%% =========================================================

max_withdrawal_limit(P) ->
    maps:get(max_withdrawal, rules(P), 0).

max_contribution_limit(P) ->
    maps:get(contribution_limit, rules(P), 0).

allows_early_withdrawal(P) ->
    maps:get(early_withdrawal, rules(P), false).

fraud_sensitivity(P) ->
    maps:get(fraud_sensitivity, rules(P), high).

%% =========================================================
%% DOMAIN HELPERS
%% =========================================================

is_financial_sensitive(P) ->
    case fraud_sensitivity(P) of
        high -> true;
        _ -> false
    end.