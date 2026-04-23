-module(chat_api_listener_bridge).
-behaviour(supervisor_bridge).

-export([start_link/0]).
-export([init/1, terminate/2]).

start_link() ->
    supervisor_bridge:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    case chat_api_listener:start_link() of
        {ok, Pid} ->
            {ok, Pid, #{listener_pid => Pid}};
        Error ->
            Error
    end.

terminate(_Reason, #{listener_pid := Pid}) when is_pid(Pid) ->
    exit(Pid, shutdown),
    ok;
terminate(_Reason, _State) ->
    ok.
