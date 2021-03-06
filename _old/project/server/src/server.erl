%% Author: Jean-Lou Dupont
%% Created: 2009-06-02
%% Description: TODO: Add description to server
-module(server).
-compile(export_all)

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% Behavioural exports
%% --------------------------------------------------------------------
-export([
	 start/0,
	 stop/0
        ]).

%% --------------------------------------------------------------------
%% Internal exports
%% --------------------------------------------------------------------
-export([]).

%% --------------------------------------------------------------------
%% Macros
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% Records
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% API Functions
%% --------------------------------------------------------------------


start() ->
	spawn(fun() -> loop([]) end).

stop() ->
    ok.

%% ====================================================================
%% Internal functions
%% ====================================================================

loop(X) ->
	