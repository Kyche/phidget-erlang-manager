%% Author: Jean-Lou Dupont
%% Created: 2009-06-19
%% Description: TODO: Add description to base
-module(base).

%%
%% Include files
%%
-include_lib("kernel/include/file.hrl").

%%
%% Exported Functions
%%
-export([
		 home/0,
		 home/1,
		 elog/2,
		 ilog/2,
		 elog/3,
		 ilog/3,
		 cond_elog/4,
		 cond_ilog/4,
		 is_debug/1,
		 safe_mkdir/1,
		 safe_mkdir/2,
		 is_dir/1,
		 is_file/1,
		 path_type/1,
		 to_list/1,
		 read_ctl_file/0,
		 read_ctl_file/1,
		 create_ctl_file/1,
		 safe_make_dirs/1,
		 safe_make_dirs/3,
		 join/1,
		 join/2,
		 add/2,
		 pvadd/2,
		 send_ready_signal/3,
		 send_synced_signal/2
		 ]).

-export([
		 kfind/2,
		 kfind/3,
		 pole/5,
		 key_present/2
		 ]).

-export([
		 do_create_ctl_file/2,
		 tmpdir/0,
		 id_dir/1,
		 ctl_file/1,
		 getport/0,
		 extract_port/1,
		 saveport/1,
		 add_to_list/2,
		 add_to_list/3,
		 send_to_list/2
		 ]).

-export([
		 send_on_count/4,
		 getvar/2,
		 getvar/3
		 ]).
%%
%% API Functions
%%

elog(X,Y) ->
	error_logger:error_msg("~p: "++X, [?MODULE|Y]).

ilog(X,Y) ->
	error_logger:info_msg("~p: "++X, [?MODULE|Y]).

elog(M, X,Y) ->
	error_logger:error_msg("~p: "++X, [M|Y]).

ilog(M, X,Y) ->
	error_logger:info_msg("~p: "++X, [M|Y]).



key_present(Key, List) ->
	case base:kfind(Key, List) of
		{Key, Value} ->
			Value;
		_ ->
			false
	end.



is_debug(Args) ->
	case base:kfind(debug, Args) of
		{debug, Value} ->
			Value;
		_ ->
			false
	end.


home() ->
    case os:getenv("PEMHOME") of
		false ->
		    os:getenv("HOME");
		DIR ->
	    	DIR
    end.

home(Env_var) ->
    case os:getenv(Env_var) of
		false ->
		    os:getenv("HOME");
		DIR ->
	    	DIR
    end.
	




is_file(Path) ->
	case path_type(Path) of
		{ok, regular} ->
			true;
		_ ->
			false
	end.



is_dir(Path) ->
	case path_type(Path) of
		{ok, directory} ->
			true;
		_ ->
			false
	end.


path_type(Path) ->
	{X, Y} = file:read_file_info(Path),
	case X of
		ok ->
			{ok, Y#file_info.type};
		_ ->
			{X, Y}
	end.


% from Yaws
id_dir(Id) ->
    filename:join([tmpdir(), "pem", to_list(Id)]).

% from Yaws
ctl_file(Id) ->
    filename:join([id_dir(Id), "CTL"]).

% from Yaws
to_list(L) when is_list(L) ->
    L;

% from Yaws
to_list(A) when is_atom(A) ->
    atom_to_list(A).

% from Yaws
tmpdir() ->
    case os:type() of
        {win32,_} ->
            case os:getenv("TEMP") of
                false ->
                    case os:getenv("TMP") of
                        false ->
                            case file:read_file_info("C:/WINNT/Temp") of
                                {error, _} ->
                                    "C:/WINDOWS/Temp";
                                {ok, _} ->
                                    "C:/WINNT/Temp"
                            end;
                        PathTMP ->
                            PathTMP
                    end;
                PathTEMP ->
                    PathTEMP
            end;
        _ ->
	    filename:join([home(), ".pem"])
    end.


read_ctl_file() ->
	Filename = ctl_file("default"),
	read_ctl_file(Filename).

read_ctl_file(Filename) ->
	file:consult(Filename).



create_ctl_file(Terms) ->
	Filename = ctl_file("default"),
	Dirname  = filename:dirname(Filename),
	case safe_make_dirs(Dirname) of
		ok ->
			do_create_ctl_file(Filename, Terms);
		{ok, _X} ->
			do_create_ctl_file(Filename, Terms);
		{X, Y} ->
			{X, Y};
		_ ->
			error
	end.

do_create_ctl_file(Filename, Terms) ->
	file:write_file(Filename, io_lib:format("~w.", [Terms])).




join([]) ->
	"";

join(String) when is_list(String), length(String) == 1 ->
	%io:format("1-join(String): [~p]~n", [String]),
	filename:join([String]);
	
join([String]) ->
	%io:format("2-join([String]): [~p]~n", [String]),
	filename:join([String]);

join(Atom) when is_atom(Atom) ->
	%io:format("3-join(Atom): [~p]~n", [Atom]),
	filename:join([Atom]);

join(String) ->
	%io:format("4-join(String): [~p]~n", [String]),
	filename:join([String]).

join([], []) ->
	"";

join(A, B) when is_list(A), is_list(B) ->
	filename:join(A,B).




safe_make_dirs(Path) ->
	Components = filename:split(Path),
	[Current|Rest] = Components,
	safe_make_dirs(Path, Current, Rest).

safe_make_dirs(_Path, [], []) ->
	ok;

safe_make_dirs(_Path, Current, []) ->
	%io:format("make_dirs: Path[~p] Current[~p]~n", [Path, Current]),
	P = ?MODULE:join(Current),
	safe_mkdir(P);

safe_make_dirs(Path, Current, Rest) ->
	%io:format("make_dirs: Path[~p] Current[~p] Rest[~p]~n", [Path, Current, Rest]),
	P = ?MODULE:join(Current),
	[RHead|NewRest] = Rest,
	NewCurrent=lists:append(Current, ["/",RHead]),
	case safe_mkdir(P) of
		ok ->
			safe_make_dirs(Path, NewCurrent, NewRest);
		{ok, _} ->
			safe_make_dirs(Path, NewCurrent, NewRest);
		{X, Y} ->
			{X, Y}
	end.



	
safe_mkdir(Dir) ->
	%io:format("safe_mkdir: Dir[~p]~n",[Dir]),
	Type = path_type(Dir),
	safe_mkdir(Dir, Type).

%% Path already exists and its a directory => nothing todo
safe_mkdir(_Dir, {ok, directory}) ->
	ok;

%% Path already exists and its NOT a directory => error
safe_mkdir(_Dir, {ok, Type}) ->
	{error, Type};
	
%% Path does not exist... create as directory then
safe_mkdir(Dir, {error, _}) ->
	file:make_dir(Dir).



add(undefined, Value) ->
	Value;

add(Var, Value) ->
	Var + Value.



pvadd(Var, Value) ->
	Count=get(Var),
	NewCount = base:add(Count, Value),
	put(Var, NewCount),
	NewCount.




cond_elog(Prob, M, X,Y) ->
	Rv = random:uniform(),
	if 
		Rv < Prob ->
			error_logger:error_msg("~p: "++X, [M|Y])
	end.
	

cond_ilog(Prob, M, X,Y) ->
	Rv = random:uniform(),
	if 
		Rv < Prob ->
			error_logger:info_msg("~p: "++X, [M|Y])
	end.


%% Returns the Port# of the
%% daemon currently running (if any)
%%
%% Returns: {port, Port}
%%
getport() ->
	{Code, X} = base:read_ctl_file(),
	Terms=X,
	case Code of 
		ok ->
			extract_port(Terms);
		_ ->
			% error code really
			{Code, X}
	end.

extract_port(Terms) ->
	case erlang:is_builtin(lists, keyfind, 3) of
		true  ->
			lists:keyfind(port,1,Terms);
		false ->
			case lists:keysearch(port,1,Terms) of
				{value, Value} ->
					Value;
				_ ->
					error
			end
	end.



kfind(_Key, []) ->
	error;

%% Searches through a list for a Key
kfind(Key, List) ->
	case erlang:is_builtin(lists, keyfind, 3) of
		true  ->
			lists:keyfind(Key,1,List);
		false ->
			case lists:keysearch(Key,1,List) of
				{value, Value} ->
					Value;
				_ ->
					error
			end
	end.
	
kfind(Key, [], Default) ->
	{Key, Default};

kfind(Key, List, Default) ->
	Ret=base:kfind(Key, List),
	case Ret of
		error ->
			{Key, Default};
		{Key, Value} ->
			{Key, Value}
	end.


%% @spec pole(Var, TrueValue, FalseValue, TrueResult, FalseResult)
pole(Var, TrueValue, FalseValue, TrueResult, FalseResult) ->
	case Var of
		TrueValue ->
			TrueResult;
		
		FalseValue ->
			FalseResult
	end.

	


%% Save the used by this daemon
saveport(Port) ->
	base:ilog(?MODULE, "saved daemon port[~p]~n",[Port]),
	base:create_ctl_file([{port, Port}]).



send_ready_signal(_From, undefined, _) ->
	ok;	

send_ready_signal(From, Recipient, Msg) ->
	Recipient ! {ready, From, Msg}.




send_synced_signal(_From, undefined) ->
	ok;

send_synced_signal(From, RootProc) ->
	RootProc ! {synced, From}.




add_to_list(List, Element) ->
	ListVar=get(List),
	add_to_list(ListVar, List, Element).

%% First element in the List
add_to_list(undefined, List, Element) ->
	put(List, [Element]);

add_to_list(ListVar, List, Element) ->
	NewList = ListVar ++ [Element],
	put(List, NewList).



send_to_list(ListName, Msg) when is_atom(ListName) ->
	List = get(ListName),
	send_to_list(List, Msg);

send_to_list([], _Msg) ->
	ok;

send_to_list(List, Msg) ->
	[Current|Rest] = List,
	Current ! Msg,
	send_to_list(Rest, Msg).



getvar(VarName, Default) ->
	VarValue=get(VarName),
	getvar(VarName, VarValue, Default).

getvar(VarName, undefined, Default) ->
	put(VarName, Default),
	Default;

getvar(_VarName, VarValue, _Default) ->
	VarValue.



send_on_count(Recipient, Msg, CountVar, TargetCount) ->
	CurrentCount=getvar(CountVar, 0),
	case CurrentCount of
		TargetCount ->
			Recipient ! Msg,
			{ok, sent};
		_ ->
			base:pvadd(CountVar, 1),
			ok
	end.
	
												   
	