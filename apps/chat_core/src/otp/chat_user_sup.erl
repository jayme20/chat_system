-module(chat_user_sup).
-behaviour(supervisor).

-export([start_link/0, start_user/1]).
-export([init/1]).



start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).



start_user(UserId) ->
    supervisor:start_child(?MODULE, [UserId]).


init([]) ->
    SupFlags = #{
        strategy => simple_one_for_one,
        intensity => 5,
        period => 30
    },
    ChildSpec = #{
        id => chat_user,
        start => {chat_user, start_link, []},
        restart => transient,
        shutdown => 5000,
        type => worker,
        modules => [chat_user]
    },
    {ok, {SupFlags, [ChildSpec]}}.