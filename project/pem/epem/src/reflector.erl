%% Author: Jean-Lou Dupont
%% Created: 2009-06-18
%% Description: Publishes messages from a Source
%%              to the target Destination subscriber(s).
%%

-module(reflector).

%% --------------------------------------------------------------------
%% API exports
%% --------------------------------------------------------------------
-export([
	start_link/0,
	stop/0,
	subscribe/2,
	unsubscribe/2	 
	]).

%% --------------------------------------------------------------------
%% Internal exports
%% --------------------------------------------------------------------
-export([
		 loop/0,
		 rpc/1,
		 publish/1,
		 do_publish/4,
		 add_client/2,
		 add_client/3,
		 remove_client/2
		 ]).

%% --------------------------------------------------------------------
%% API Functions
%% --------------------------------------------------------------------
subscribe(Client, Msgtype) when is_atom(Msgtype) ->
	Ret = rpc({subscribe, Client, Msgtype}),
	base:ilog(?MODULE, "subscribe: Client[~p] Msgtype[~p] Ret[~p]~n", [Client, Msgtype, Ret]),
	Ret;

%% List of subscriptions
subscribe(Client, Subs) ->
	Ret = rpc({subscribe, Client, Subs}),
	base:ilog(?MODULE, "subscribe: Client[~p] Subs[~p] Ret[~p]~n", [Client, Subs, Ret]),
	Ret.


unsubscribe(Client, Msgtype) ->
	Ret = rpc({unsubscribe, Client, Msgtype}),
	base:elog(?MODULE, "unsubscribe: Client[~p] Msgtype[~p] Ret[~p]~n", [Client, Msgtype, Ret]),
	Ret.

rpc(Q) ->
	Pid = self(),
	try ?MODULE ! {Pid, Q} of
		{Pid, _} ->
			ok;
		Other ->
			Other
	catch
		_:_ ->
			err
	end.

%% ====================================================================!
%% API functions
%% ====================================================================!

start_link() ->
	Pid = spawn_link(?MODULE, loop, []),
	register( ?MODULE, Pid ),
	{ok, Pid}.

stop() ->
	base:elog(?MODULE, "STOP CALLED!~n"),
    rpc({stop}).


%% ==========
%% Func: loop
%% ==========
loop() ->
	receive
		{_From, {stop}} ->
			base:elog(?MODULE, "received STOP~n"),
			exit(self(), ok);

		%% SUBSCRIBE command
		{From, {subscribe, Client, X}} ->
			add_client(Client, X),
			
			%provide feedback to caller
			From ! {reflector, subscribe, ok},
			ok;

		%% UNSUBSCRIBE command
		{From, {unsubscribe, Client, Msgtype}} ->
			remove_client(Client, Msgtype),
			From ! {reflector, unsubscribe, ok},
			ok;
		
		%% Message publication
		{_From, {Msgtype, Msg, Timestamp}} ->
			publish({Msgtype, Msg, Timestamp}),
			ok;

		Error ->
			base:elog(?MODULE, "unsupported message, [~p]~n", [Error]),
			Error

	end,
	?MODULE:loop().

%% =======================================================================================
%% SUBSCRIBE/UNSUBSCRIBE API
%% =======================================================================================

add_client(_Client, []) ->
	ok;

add_client(Client, Msgtype) when is_atom(Msgtype) ->
	Liste = get({msgtype,Msgtype}),
	add_client(Liste, Client, Msgtype);

add_client(Client, Subs) ->
	[Msgtype|Rest] = Subs,
	add_client(Client, Msgtype),
	add_client(Client, Rest).

%no Client yet for Msgtype
add_client(undefined, Client, Msgtype) when is_atom(Msgtype) ->
	New_liste = [Client],
	put({msgtype,Msgtype}, New_liste),
	ok;

add_client(Liste, Client, Msgtype) when is_atom(Msgtype) ->
	
	% we do not want duplicates
	Filtered_liste = Liste -- [Client],
	
	New_liste = Filtered_liste ++ [Client],
	put({msgtype, Msgtype}, New_liste),
	ok.



remove_client(undefined, _) ->
	ok;

remove_client(Client, Msgtype) ->
	base:ilog(?MODULE, "remove_client: Client[~p] Msgtype[~p]~n", [Client, Msgtype]),
	Liste = get(Msgtype),
	Updated = Liste--[Client],
	put({msgtype, Msgtype}, Updated),
	ok.

%% =======================================================================================
%% PUBLISH API
%% =======================================================================================

publish(M) ->
	%%base:ilog(?MODULE, "publish Msg[~p]~n", [M]),
	{Msgtype, Msg, Timestamp} = M,
	Liste = get({msgtype, Msgtype}),
	do_publish(Liste, Msgtype, Msg, Timestamp).


do_publish([], _Msgtype, _, _) ->
	%%base:ilog(?MODULE, "do_publish: NO MORE subscribers for [~p]~n", [Msgtype]),
	ok;


do_publish(undefined, Msgtype, _, _) ->
	base:ilog(?MODULE, "do_publish: no subscribers for [~p]~n", [Msgtype]),
	ok;


do_publish(Liste, Msgtype, Msg, Timestamp) ->
	%%base:ilog(?MODULE, "do_publish, Msgtype[~p] liste[~p]~n", [Msgtype, Liste]),
	[Current|Rest] = Liste,
	%%base:ilog(?MODULE, "publish, TO[~p] Msgtype[~p] Msg[~p]~n", [Current, Msgtype, Msg]),
	
	try	Current ! {Msgtype, Msg, Timestamp} of
		{Msgtype, Msg, Timestamp} ->
			ok;
		Other ->
			base:elog(?MODULE,"do_publish: result[~p]~n", [Other]),
			remove_client(Current, Msgtype)
	catch
		X:Y ->
			base:elog(?MODULE, "do_publish: ERROR sending, X[~p] Y[~p]~n", [X, Y]),
			remove_client(Current, Msgtype)
	end,
	do_publish(Rest, Msgtype, Msg, Timestamp).

