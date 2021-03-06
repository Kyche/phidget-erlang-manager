%% Author:      Jean-Lou Dupont
%% Created:     2009-06-28
%% Description: Message Switch support functions

-module(switch).

%%
%% API Functions
%%
-export([
		 subscribe/2,
		 publish/3
		 ]).

-export([
		 add_subscriber/2
		 ]).


%%
%% Local Functions
%%
-export([
		 to_switch/3,
		 add_type/1,
		 do_publish_list/5,
		 do_publish/3,
		 do_add_subscriber/2
		 ]).


%% !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
%%      API
%% !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


%% Subscription is not synchronous: the caller will
%% be serviced asynchronously i.e. don't count on
%% the ability to receive message(s) from subscribed
%% types after this function call returns.
%%
%% @spec subscribe(Type)
%%
subscribe(From, Type) when is_atom(From) ->
	to_switch(From, subscribe, Type).



%%
%% @spec publish(From, MsgType, Msg)
%%
publish(From, MsgType, Msg) when is_atom(From), is_atom(MsgType) ->
	to_switch(From, publish, {MsgType, Msg}).


%% !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
%%   INTERNAL
%% !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

to_switch(From, Cmd, Msg) ->
	
	%%base:ilog(?MODULE, "to_switch: From[~p] Cmd[~p] Msg[~p]~n", [From, Cmd, Msg]),
	try switch ! {From, Cmd, Msg} of
		{From, Cmd, Msg} ->
			ok;
		
		Error ->
			base:elog(?MODULE, "to_switch: ERROR, From[~p] Cmd[~p] Msg[~p] ERROR[~p]~n", [From, Cmd, Msg, Error]),
			error
	catch
		X:Y ->
			base:elog(?MODULE, "to_switch: EXCEPTION, From[~p] Cmd[~p] Msg[~p] X[~p] Y[~p]~n", [From, Cmd, Msg, X, Y]),
			error
	end.



%% !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
%%   SHOULD ONLY BE USED BY THE SWITCH PROCESS
%% !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
			  

add_subscriber(Client, undefined) when is_atom(Client) ->
	base:elog(?MODULE, "add_subscriber: invalid type~n",[]),
	ok;

%%
%% @spec add_subscriber(Client, Type)
%%       Client = Atom()
%%       Type   = Atom()
add_subscriber(Client, Type) when is_atom(Type), is_atom(Client) ->
	do_add_subscriber(Client, Type),
	Client ! {switch, subscribed};


add_subscriber(Client, []) when is_atom(Client) ->
	%%base:ilog(?MODULE, "finished subscribing Client[~p]~n", [Client]),
	Client ! {switch, subscribed},
	ok;

add_subscriber(Client, TypeList) when is_atom(Client), is_list(TypeList) ->
	%%base:ilog(?MODULE, "add_subscriber: Client[~p] List[~p]~n", [Client, TypeList]),
	[H|T] = TypeList,
	do_add_subscriber(Client, H),
	add_subscriber(Client, T).




do_add_subscriber(Client, Type) ->
	base:add_to_list_no_duplicates({msgtype, Type}, Client),
	switch:add_type(Type).



%% Adds a Type to the registered MsgTypes list, no duplicates
add_type(Type) ->
	base:add_to_list_no_duplicates(msgtypes, Type),
	ok.




do_publish(From, MsgType, Msg) when is_atom(From), is_atom(MsgType) ->
	%%base:ilog(?MODULE,"do_publish: From[~p] MsgType[~p] Msg[~p]~n", [From, MsgType, Msg]),
	ToList = base:getvar({msgtype, MsgType}, []),
	case ToList of
		[] ->
			ok;
		_ ->
		[To|Rest] = ToList,
		do_publish_list(To, Rest, From, MsgType, Msg)
	end.




do_publish_list([], [], From, MsgType, _Msg) when is_atom(From), is_atom(MsgType) ->
	ok;											  

do_publish_list([], _, From, MsgType, _Msg) when is_atom(From), is_atom(MsgType) ->
	ok;											  


do_publish_list(CurrentTo, RestTo, From, MsgType, Msg) when is_atom(From), is_atom(MsgType) ->
	%%base:ilog(?MODULE, "do_publish_list: CurrentTo[~p] RestTo[~p] From[~p] MsgType[~p] Msg[~p]~n", [CurrentTo, RestTo, From, MsgType, Msg]),
	try CurrentTo ! {From, MsgType, Msg} of
		{From, MsgType, Msg} ->
			ok;
		Error ->
			base:elog(?MODULE, "do_publish: Error[~p], From[~p] MsgType[~p] Msg[~p]~n", [Error, From, MsgType, Msg])
	catch
		X:Y ->
			base:elog(?MODULE, "do_publish: EXCEPTION, From[~p] MsgType[~p] Msg[~p] X[~p] Y[~p]~n", [From, MsgType, Msg, X, Y])
	end,
	case RestTo of 
		[] ->
			ok;
		_ ->
			[NewTo|NewRest] = RestTo,
			%%base:ilog(?MODULE, "do_publish_list: NewTo[~p] NewRest[~p]~n", [NewTo, NewRest]),
			do_publish_list(NewTo, NewRest, From, MsgType, Msg)
	end.



