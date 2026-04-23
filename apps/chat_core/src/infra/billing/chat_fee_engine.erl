-module(chat_fee_engine).

%% =====================================================
%% FEE ENGINE (PURE LOGIC)
%% =====================================================
%% This module NEVER stores state.
%% It only calculates fees.
%% =====================================================

-export([
    contribution_fee/2,
    withdrawal_fee/2,
    cycle_fee/2
]).

%% -----------------------------------------------------
%% CONTRIBUTION FEE
%% -----------------------------------------------------
%% Amount-based fee (Kenyan microfinance friendly)
contribution_fee(Amount, RiskTier) ->
    Rate =
        case RiskTier of
            low -> 0.005;     %% 0.5%
            medium -> 0.01;   %% 1%
            high -> 0.02      %% 2%
        end,
    Fee = Amount * Rate,
    min(Fee, 50). %% cap fee (important for adoption)

%% -----------------------------------------------------
%% WITHDRAWAL FEE
%% -----------------------------------------------------
withdrawal_fee(Amount, RiskTier) ->
    Rate =
        case RiskTier of
            low -> 0.005;
            medium -> 0.01;
            high -> 0.015
        end,
    min(Amount * Rate, 100).

%% -----------------------------------------------------
%% CYCLE MANAGEMENT FEE
%% -----------------------------------------------------
cycle_fee(TotalPool, DurationMonths) ->
    BaseRate =
        case DurationMonths of
            1 -> 0.01;
            3 -> 0.015;
            6 -> 0.02;
            _ -> 0.03
        end,
    TotalPool * BaseRate.