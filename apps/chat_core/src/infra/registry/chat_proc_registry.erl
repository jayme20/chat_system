-module(chat_proc_registry).
-behaviour(gen_server).

-export([
    start_link/0,
    register_name/2,
    unregister_name/1,
    whereis_name/1,
    send/2,
    user_name/1,
    group_name/1
]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

register_name(Name, Pid) when is_pid(Pid) ->
    gen_server:call(?MODULE, {register_name, Name, Pid}).

unregister_name(Name) ->
    gen_server:call(?MODULE, {unregister_name, Name}).

whereis_name(Name) ->
    gen_server:call(?MODULE, {whereis_name, Name}).

send(Name, Msg) ->
    case whereis_name(Name) of
        undefined ->
            exit({badarg, {Name, Msg}});
        Pid ->
            Pid ! Msg,
            Pid
    end.

user_name(UserId) ->
    {chat_user, UserId}.

group_name(GroupId) ->
    {chat_group, GroupId}.

init([]) ->
    {ok, #{names => #{}, pids => #{}}}.

handle_call({register_name, Name, Pid}, _From, State) ->
    case is_process_alive(Pid) of
        false ->
            {reply, {error, dead_pid}, State};
        true ->
            Names = maps:get(names, State),
            Pids = maps:get(pids, State),
            case maps:is_key(Name, Names) of
                true ->
                    {reply, {error, already_registered}, State};
                false ->
                    MonRef = erlang:monitor(process, Pid),
                    NewNames = maps:put(Name, {Pid, MonRef}, Names),
                    NewPids = maps:put(Pid, Name, Pids),
                    {reply, true, State#{names => NewNames, pids => NewPids}}
            end
    end;
handle_call({unregister_name, Name}, _From, State) ->
    {reply, ok, unregister_name_internal(Name, State)};
handle_call({whereis_name, Name}, _From, State) ->
    Names = maps:get(names, State),
    case maps:get(Name, Names, undefined) of
        {Pid, _MonRef} ->
            {reply, Pid, State};
        undefined ->
            {reply, undefined, State}
    end.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({'DOWN', MonRef, process, Pid, _Reason}, State) ->
    Names = maps:get(names, State),
    Pids = maps:get(pids, State),
    case maps:get(Pid, Pids, undefined) of
        undefined ->
            {noreply, State};
        Name ->
            case maps:get(Name, Names, undefined) of
                {Pid, MonRef} ->
                    NewNames = maps:remove(Name, Names),
                    NewPids = maps:remove(Pid, Pids),
                    {noreply, State#{names => NewNames, pids => NewPids}};
                _ ->
                    {noreply, State}
            end
    end;
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

unregister_name_internal(Name, State) ->
    Names = maps:get(names, State),
    Pids = maps:get(pids, State),
    case maps:get(Name, Names, undefined) of
        {Pid, MonRef} ->
            erlang:demonitor(MonRef, [flush]),
            State#{
                names => maps:remove(Name, Names),
                pids => maps:remove(Pid, Pids)
            };
        undefined ->
            State
    end.
