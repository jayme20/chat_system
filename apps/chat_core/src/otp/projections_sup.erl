-module(projections_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

%% =====================================================
%% STARTER
%% =====================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% =====================================================
%% SUPERVISOR INIT
%% =====================================================

init(_Args) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 5,
        period => 10
    },

    %% -----------------------------------------------------
    %% PROJECTIONS WORKERS
    %% Each projection is a read-model derived from events
    %% -----------------------------------------------------

    Children = [

        %% Treasury Projection (group financial overview)
        #{
            id => chat_treasury_projection,
            start => {chat_treasury_projection, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [chat_treasury_projection]
        },

        %% Leaderboard Projection (members ranked by contributions)
        #{
            id => chat_leaderboard_projection,
            start => {chat_leaderboard_projection, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [chat_leaderboard_projection]
        },

        %% Insights Projection (analytics / engagement / activity)
        #{
            id => chat_insights_projection,
            start => {chat_insights_projection, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [chat_insights_projection]
        },

        %% Revenue Ledger Projection (financial audit + reconciliation view)
        #{
            id => chat_revenue_ledger,
            start => {chat_revenue_ledger, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [chat_revenue_ledger]
        },

        %% Treasury State Aggregator (fast read model for UI)
        #{
            id => chat_treasury,
            start => {chat_treasury, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [chat_treasury]
        }
    ],

    {ok, {SupFlags, Children}}.