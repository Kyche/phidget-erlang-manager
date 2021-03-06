%% Author: Jean-Lou Dupont
%% Created: 2009-09-08
%% Description: epem supervisor 
-module(epem_sup).
-define(NAME, epem).

%% ALL MODULES
-define(MODS,   [hwswitch, log, clock, config, appctl, manager, ifk, mswitch_bridge, logpolicer, journal]).

%% MODULES which require HWSWITCH access
-define(HSMODS, [log, clock, config, appctl, manager, ifk, mswitch_bridge, logpolicer, journal]).

%% MODULES part of the configuration process
-define(CFGMODS, [log, appctl, manager, ifk, mswitch_bridge, logpolicer, journal]).


-behavior(supervisor).


%% --------------------------------------------------------------------
%% External exports
%% --------------------------------------------------------------------
-export([
	 init/1,
	 start_link/0,
	 start_link/1
	,hsmods/0
        ]).

	
	

%% ====================================================================
%% Server functions
%% ====================================================================
start_link() ->
	start_link([]).

start_link(Args) ->
	process_flag(trap_exit, true),
	supervisor:start_link({local, ?MODULE}, ?MODULE, Args).



%% --------------------------------------------------------------------
%% Func: init/1
%% Returns: {ok,  {SupFlags,  [ChildSpec]}} |
%%          ignore                          |
%%          {error, Reason}
%% --------------------------------------------------------------------
init(_Args) ->

	Child_base   = mcd(?NAME),
    Child_logger = mc(log, {logfilename, "/var/log/epem.log"} ),
    Child_switch = mc(hwswitch, {mods, hsmods()}),
    Child_clock =  mc(clock),
	Child_appctl = mc(appctl, cfgmods()),
	Child_config = mc(config, cfgmods()),
	Child_manager= mc(manager),
	Child_ifk    = mc(ifk),
	Child_mb     = mc(mswitch_bridge),
	Child_lp     = mc(logpolicer),
	Child_journal= mc(journal),

	
	Children = [Child_base, Child_logger, Child_switch, Child_clock, Child_appctl, Child_config
			   ,Child_manager, Child_ifk
			   ,Child_mb
			   ,Child_lp
			   ,Child_journal
				],
	
	
    {ok,{{one_for_one,5,1}, Children }}.



%% ====================================================================
%% HELPERS
%% ====================================================================

%% @doc Returns the list of modules for which
%%		'hwswitch' access is required.
%%
hsmods() ->
	Fun = fun(Mod) ->
			[mm(Mod)]			
		end,
	lists:flatmap(Fun, ?HSMODS)++[?NAME].


%% @doc Returns the list of modules which
%%		are part of the configuration process.
%%
cfgmods() ->
	Fun = fun(Mod) ->
			[mm(Mod)]
		  end,
	lists:flatmap(Fun, ?CFGMODS)++[?NAME].


make_atom(List) ->
	make_atom(List, []).

make_atom([], Acc) ->
	erlang:list_to_atom(Acc);

make_atom([H|T], Acc) when is_atom(H) ->
	L=erlang:atom_to_list(H),
	make_atom(T, Acc++L);

make_atom([H|T], Acc) when is_list(H) ->
	make_atom(T, Acc++H).


mm(Name) ->
	make_atom([?NAME, '_', Name]).


mcd(M) ->
	{M,{M, start_link,[]},permanent,2000,worker,[M]}.


mc(Mod) ->
	M=mm(Mod),
	{M,{M, start_link,[]},permanent,2000,worker,[M]}.

mc(Mod, Params) ->
	M=mm(Mod),
	{M,{M, start_link, [Params]},permanent,2000,worker,[M]}.

	