-module(chat_group_sup).

-behaviour(supervisor).

-export([start_link/0]).
-export([start_group/1]).
-export([stop_group/1]).
-export([init/1]).



start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

start_group(GroupId) ->
    supervisor:start_child(?MODULE, [GroupId]).

stop_group(GroupId) ->
    case chat_group:whereis(GroupId) of
        undefined ->
            {error, not_found};
        Pid when is_pid(Pid) ->
            supervisor:terminate_child(?MODULE, Pid)
    end.


init([]) ->

    SupFlags = #{
        strategy => simple_one_for_one,
        intensity => 20,
        period => 10
    },
    ChildSpecs = [
        #{
            id => chat_group,
            start => {chat_group, start_link, []},
            restart => transient,
            shutdown => 5000,
            type => worker,
            modules => [chat_group]
        }
    ],
    {ok, {SupFlags, ChildSpecs}}.