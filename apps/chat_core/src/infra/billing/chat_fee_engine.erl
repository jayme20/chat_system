-module(chat_fee_engine).

%% =====================================================
%% FEE ENGINE (PURE LOGIC)
%% =====================================================
%% This module NEVER stores state.
%% It only calculates fees.
%% =====================================================

-export([
    calculate_contribution_fee/2,
    calculate_withdrawal_fee/2,
    apply_fee/2,
    contribution_fee/2,
    withdrawal_fee/2,
    cycle_fee/2
]).


contribution_fee(Amount, RiskTier) ->
    Rate =
        case RiskTier of
            low -> 0.005;     %% 0.5%
            medium -> 0.01;   %% 1%
            high -> 0.02      %% 2%
        end,
    Fee = Amount * Rate,
    min(Fee, 50). %% cap fee (important for adoption)


withdrawal_fee(Amount, RiskTier) ->
    Rate =
        case RiskTier of
            low -> 0.005;
            medium -> 0.01;
            high -> 0.015
        end,
    min(Amount * Rate, 100).


cycle_fee(TotalPool, DurationMonths) ->
    BaseRate =
        case DurationMonths of
            1 -> 0.01;
            3 -> 0.015;
            6 -> 0.02;
            _ -> 0.03
        end,
    TotalPool * BaseRate.


calculate_contribution_fee(Amount, Context) when is_integer(Amount), Amount > 0 ->
    RiskTier = context_risk_tier(Context),
    round_fee(contribution_fee(Amount, RiskTier));
calculate_contribution_fee(_Amount, _Context) ->
    0.

calculate_withdrawal_fee(Amount, Context) when is_integer(Amount), Amount > 0 ->
    RiskTier = context_risk_tier(Context),
    round_fee(withdrawal_fee(Amount, RiskTier));
calculate_withdrawal_fee(_Amount, _Context) ->
    0.

apply_fee(Amount, Fee)
    when is_integer(Amount), is_integer(Fee), Amount >= 0, Fee >= 0 ->
    erlang:max(0, Amount - Fee);
apply_fee(Amount, _Fee) when is_integer(Amount), Amount >= 0 ->
    Amount;
apply_fee(_, _) ->
    0.



context_risk_tier(#{risk_tier := Tier}) ->
    normalize_risk_tier(Tier);
context_risk_tier(#{risk_score := Score}) when is_integer(Score), Score >= 80 ->
    high;
context_risk_tier(#{risk_score := Score}) when is_integer(Score), Score >= 40 ->
    medium;
context_risk_tier(_) ->
    low.

normalize_risk_tier(low) -> low;
normalize_risk_tier(medium) -> medium;
normalize_risk_tier(high) -> high;
normalize_risk_tier(<<"low">>) -> low;
normalize_risk_tier(<<"medium">>) -> medium;
normalize_risk_tier(<<"high">>) -> high;
normalize_risk_tier(_) -> low.

round_fee(Fee) when is_number(Fee) ->
    erlang:round(Fee);
round_fee(_) ->
    0.