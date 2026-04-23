-module(chat_core_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->

    Children = [

        %% Boot / Infrastructure initialization
        #{
            id => chat_boot_sup,
            start => {chat_boot_sup, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => supervisor,
            modules => [chat_boot_sup]
        },

        %% Registry Layer (process registry / ETS / group lookup)
        #{
            id => chat_registry_srv,
            start => {chat_registry_srv, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [chat_registry_srv]
        },
        #{
            id => chat_proc_registry,
            start => {chat_proc_registry, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [chat_proc_registry]
        },
        #{
            id => chat_telemetry_poller,
            start => {chat_telemetry_poller, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [chat_telemetry_poller]
        },
            %% User supervision tree
        #{
            id => chat_user_sup,
            start => {chat_user_sup, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => supervisor,
            modules => [chat_user_sup]
        },

        %% Group supervision tree
        #{
            id => chat_group_sup,
            start => {chat_group_sup, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => supervisor,
            modules => [chat_group_sup]
        },

        %% Event supervision tree 
        #{
            id => chat_event_sup,
            start => {chat_event_sup, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => supervisor,
            modules => [chat_event_sup]
        },

        %% Read-model projections supervision tree
        #{
            id => projections_sup,
            start => {projections_sup, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => supervisor,
            modules => [projections_sup]
        },

        %% M-Pesa infrastructure workers supervision tree
        #{
            id => mpesa_sup,
            start => {mpesa_sup, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => supervisor,
            modules => [mpesa_sup]
        }
    ],

    {ok, {#{strategy => one_for_one,
            intensity => 5,
            period => 10}, Children}}.