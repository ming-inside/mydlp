%%%
%%%    Copyright (C) 2010 Huseyin Kerem Cevahir <kerem@mydlp.com>
%%%
%%%--------------------------------------------------------------------------
%%%    This file is part of MyDLP.
%%%
%%%    MyDLP is free software: you can redistribute it and/or modify
%%%    it under the terms of the GNU General Public License as published by
%%%    the Free Software Foundation, either version 3 of the License, or
%%%    (at your option) any later version.
%%%
%%%    MyDLP is distributed in the hope that it will be useful,
%%%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%%%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%%%    GNU General Public License for more details.
%%%
%%%    You should have received a copy of the GNU General Public License
%%%    along with MyDLP.  If not, see <http://www.gnu.org/licenses/>.
%%%--------------------------------------------------------------------------

%%%-------------------------------------------------------------------
%%% @author H. Kerem Cevahir <kerem@mydlp.com>
%%% @copyright 2011, H. Kerem Cevahir
%%% @doc Worker for mydlp.
%%% @end
%%%-------------------------------------------------------------------

-module(mydlp_spool).
-author("kerem@mydlp.com").
-behaviour(gen_server).

-include("mydlp.hrl").

%% API
-export([start_link/0,
	create_spool/1,
%	register_consumer/2,
	push/2,
	pop/1,
	poppush/1,
	delete/1,
	is_empty/1,
	stop/0]).

%% gen_server callbacks
-export([init/1,
	handle_call/3,
	handle_cast/2,
	handle_info/2,
	terminate/2,
	code_change/3]).

-include_lib("eunit/include/eunit.hrl").

-record(state, {
	spools = dict:new()
	}).

-record(spool, {
	name = "",
	consumer
	}).

-define(SPOOL_DIR(SpoolName), ?CFG(spool_dir) ++ "/" ++ SpoolName).

%%%% API

create_spool(SpoolName) -> gen_server:cast(?MODULE, {create_spool, SpoolName}).

delete(Ref) -> gen_server:cast(?MODULE, {delete, Ref}).

%register_consumer(SpoolName, ConsumeFun) -> gen_server:cast(?MODULE, {register_consumer, SpoolName, ConsumeFun}).

push(SpoolName, Item) -> gen_server:call(?MODULE, {push, SpoolName, Item}).

is_empty(SpoolName) -> gen_server:call(?MODULE, {is_empty, SpoolName}).

pop(SpoolName) -> gen_server:call(?MODULE, {pop, SpoolName}).

poppush(SpoolName) -> gen_server:call(?MODULE, {poppush, SpoolName}).

%%%%%%%%%%%%%% gen_server handles

handle_call({pop, SpoolName}, _From, #state{spools = Spools} = State) ->
	case dict:is_key(SpoolName, Spools) of
		true ->	Ret = case file:list_dir(?SPOOL_DIR(SpoolName)) of
				{ok, []} -> {ierror, cannot_list_spool_contents};
				{ok, [FN0|_]} -> FN = ?SPOOL_DIR(SpoolName) ++ "/" ++ FN0,
						{ok, Bin} = file:read_file(FN),
						Item = erlang:binary_to_term(Bin),
						ok = file:delete(FN),
						{ok, Item};
				{error, Error} -> {ierror, Error} end,
			{reply, Ret, State};
		false -> ?ERROR_LOG("Spool does not exist: Name: "?S" Dir: "?S, 
				[SpoolName, ?SPOOL_DIR(SpoolName)]),
			{reply, {ierror, spool_does_not_exist}, State}
			end;

handle_call({is_empty, SpoolName}, _From, #state{spools = Spools} = State) ->
	case dict:is_key(SpoolName, Spools) of
		true ->	Ret = case file:list_dir(?SPOOL_DIR(SpoolName)) of
				{ok, []} -> {ok, true};
				{ok, _Else} -> {ok, false};
				{error, Error} -> {ierror, Error} end,
			{reply, Ret, State};
		false -> ?ERROR_LOG("Spool does not exist: Name: "?S" Dir: "?S, 
				[SpoolName, ?SPOOL_DIR(SpoolName)]),
			{reply, {ierror, spool_does_not_exist}, State}
			end;

handle_call({poppush, SpoolName}, _From, #state{spools = Spools} = State) ->
	case dict:is_key(SpoolName, Spools) of
		true ->	Ret = case file:list_dir(?SPOOL_DIR(SpoolName)) of
				{ok, []} -> {ierror, cannot_list_spool_contents};
				{ok, [FN0|_]} -> FN = ?SPOOL_DIR(SpoolName) ++ "/" ++ FN0,
						{ok, Bin} = file:read_file(FN),
						Item = erlang:binary_to_term(Bin),
						NRef = now(),
						Ref = {SpoolName, NRef},
						FP = mydlp_api:ref_to_fn(?SPOOL_DIR(SpoolName), "item", NRef),
						case file:rename(FN, FP) of
							ok -> {ok, Ref, Item};
							{error, Error} -> {ierror, Error} end;
				{error, Error2} -> {ierror, Error2} end,
			{reply, Ret, State};
		false -> ?ERROR_LOG("Spool does not exist: Name: "?S" Dir: "?S, 
				[SpoolName, ?SPOOL_DIR(SpoolName)]),
			{reply, {ierror, spool_does_not_exist}, State}
			end;

handle_call({push, SpoolName, Item}, _From, #state{spools = Spools} = State) ->
	case dict:is_key(SpoolName, Spools) of
		true ->	Bin = erlang:term_to_binary(Item, [compressed]),
			NRef = now(),
			Ref = {SpoolName, NRef},
			FP = mydlp_api:ref_to_fn(?SPOOL_DIR(SpoolName), "item", NRef),
			ok = file:write_file(FP, Bin),
			{reply, {ok, Ref}, State};
		false -> ?ERROR_LOG("Spool does not exist: Name: "?S" Dir: "?S, 
				[SpoolName, ?SPOOL_DIR(SpoolName)]),
			{reply, {ierror, spool_does_not_exist}, State}
			end;

handle_call(stop, _From, State) ->
	{stop, normalStop, State};

handle_call(_Msg, _From, State) ->
	{noreply, State}.

handle_cast({delete, {SpoolName, NRef}}, #state{spools = Spools} = State) ->
	case dict:is_key(SpoolName, Spools) of
		true ->	FP = mydlp_api:ref_to_fn(?SPOOL_DIR(SpoolName), "item", NRef),
			case file:delete(FP) of
				ok ->  ok;
				Error -> ?ERROR_LOG("Can not delete spool ref. SpoolName: "?S" RefPath: "?S" Error: "?S"", 
					[SpoolName, FP, Error]) end;
		false -> ?ERROR_LOG("Spool does not exist: Name: "?S" Dir: "?S, 
				[SpoolName, ?SPOOL_DIR(SpoolName)]) end,
	{noreply, State};

handle_cast({create_spool, SpoolName}, #state{spools = Spools} = State) ->
	case dict:is_key(SpoolName, Spools) of
		true -> {noreply, State};
		false -> case filelib:ensure_dir(?SPOOL_DIR(SpoolName) ++ "/") of
				ok -> NewSpool = #spool{name=SpoolName},
					{noreply, State#state{spools=dict:store(SpoolName, NewSpool, Spools)}};
				Error -> ?ERROR_LOG("Can not create spool directory. Name: "?S" Dir: "?S" Error: "?S"", 
						[SpoolName, ?SPOOL_DIR(SpoolName), Error]),
					{noreply, State}
				end
		end;

handle_cast(_Msg, State) ->
	{noreply, State}.

handle_info({async_reply, Reply, From}, State) ->
	gen_server:reply(From, Reply),
	{noreply, State};

handle_info(sync_now, State) ->
	sync(),
	call_timer(),
        {noreply, State};

handle_info(_Info, State) ->
	{noreply, State}.

%%%%%%%%%%%%%%%% Implicit functions

start_link() ->
	case gen_server:start_link({local, ?MODULE}, ?MODULE, [], []) of
		{ok, Pid} -> {ok, Pid};
		{error, {already_started, Pid}} -> {ok, Pid};
		Else -> Else
	end.

stop() ->
	gen_server:call(?MODULE, stop).

init([]) ->
	case filelib:ensure_dir(?CFG(spool_dir) ++ "/") of
		ok -> {ok, #state{}};
		Error -> Error end.

terminate(_Reason, _State) ->
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

call_timer() -> call_timer(?CFG(sync_interval)).

call_timer(Interval) -> timer:send_after(Interval, sync_now).

sync() ->
	RevisionI = mydlp_api:get_client_policy_revision_id(),
	RevisionS = integer_to_list(RevisionI),
	Url = "https://" ++ ?CFG(management_server_address) ++ "/mydlp-web-manager/sync.php?rid=" ++ RevisionS,
	case catch http:request(Url) of
		{ok, {{_HttpVer, Code, _Msg}, _Headers, Body}} -> 
			case {Code, Body} of
				{200, <<>>} -> ?ERROR_LOG("SYNC: Empty response: Url="?S"~n", [Url]);
				{200, <<"up-to-date", _/binary>>} -> ok;
				{200, CDBS} -> 	CDBBin = list_to_binary(CDBS),
						mydlp_api:use_client_policy(CDBBin);
				{Else1, _Data} -> ?ERROR_LOG("SYNC: An error occured during HTTP req: Code="?S"~n", [Else1]) end;
		Else -> ?ERROR_LOG("SYNC: An error occured during HTTP req: Obj="?S"~n", [Else]) end,
	ok.


