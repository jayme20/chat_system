-module(chat_group_registry).

-behaviour(gen_server).

-export([
    start_link/0,
    register_group/2,
    lookup_group/1,
    remove_group/1
]).

-export([init/1, handle_call/3, handle_cast/2, terminate/2, code_change/3]).

-record(state, {
    groups = #{}
}).

%% =====================================================
%% STARTUP
%% =====================================================

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, #state{}}.

%% =====================================================
%% API
%% =====================================================

register_group(GroupId, Pid) ->
    gen_server:call(?MODULE, {register, GroupId, Pid}).

lookup_group(GroupId) ->
    gen_server:call(?MODULE, {lookup, GroupId}).

remove_group(GroupId) ->
    gen_server:call(?MODULE, {remove, GroupId}).

%% =====================================================
%% CALL HANDLERS
%% =====================================================

handle_call({register, GroupId, Pid}, _From, S) ->
    NewMap = maps:put(GroupId, Pid, S#state.groups),
    {reply, ok, S#state{groups = NewMap}};

handle_call({lookup, GroupId}, _From, S) ->
    Reply = maps:get(GroupId, S#state.groups, undefined),
    {reply, Reply, S};

handle_call({remove, GroupId}, _From, S) ->
    NewMap = maps:remove(GroupId, S#state.groups),
    {reply, ok, S#state{groups = NewMap}}.

%% =====================================================
%% CAST
%% =====================================================

handle_cast(_Msg, State) ->
    {noreply, State}.

%% =====================================================
%% OTP
%% =====================================================

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.