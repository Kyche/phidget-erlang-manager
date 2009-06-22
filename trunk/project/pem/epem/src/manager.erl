%% Author: Jean-Lou Dupont
%% Created: 2009-06-18
%% Description: TODO: Add description to manager
-module(manager).

%% --------------------------------------------------------------------
%% MACROS
%% --------------------------------------------------------------------
-define(DRV_MNG, "pem_drv_mng_debug").

%% --------------------------------------------------------------------
%% Behavioural exports
%% --------------------------------------------------------------------
-export([
	 start_link/0,
	 stop/0
        ]).

%% --------------------------------------------------------------------
%% Internal exports
%% --------------------------------------------------------------------
-export([
		 loop/0,
		 loop_drv/1,
		 start_drv/0,
		 mng_drv/1,
		 send_to_reflector/1,
		 send_to_reflector/2
		 ]).

%% --------------------------------------------------------------------
%% Macros
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% Records
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% API Functions
%% --------------------------------------------------------------------


%% ====================================================================!
%% External functions
%% ====================================================================!
start_link() ->
	Pid = spawn_link(?MODULE, loop, []),
	register( ?MODULE, Pid ),
	?MODULE ! {driver, dostart},
	%%error_logger:info_msg("manager:start_link: PID[~p]~n", [Pid]),
	{ok, Pid}.

start_drv() ->
	_Pid_drv = spawn(?MODULE, mng_drv, [?DRV_MNG]),
	%%error_logger:info_msg("manager:start_drv: Pid[~p]~n", [Pid_drv]),
	ok.

mng_drv(ExtPrg) ->
    process_flag(trap_exit, true),
    Port = open_port({spawn, ExtPrg}, [{packet, 2}, binary, exit_status]),
    loop_drv(Port).


%% --------------------------------------------------------------------
%% Func: stop/0
%% Returns: any
%% --------------------------------------------------------------------
stop() ->
    ?MODULE ! stop.

%% ====================================================================
%% Internal functions
%% ====================================================================

loop() ->
	receive
		
		{driver, dostart} ->
			start_drv();
		
		{driver, crashed} ->
			error_logger:error_msg("~p: driver crashed~n", [?MODULE]),
			start_drv();

		stop ->
			exit(ok);
		
		Error ->
			error_logger:warning_msg("manager:loop: unsupported message"),
			Error
	end,
	loop().

%% Message loop for receiving messages from pem_drv_mng
%% ====================================================
loop_drv(Port) ->
	receive
		
		% port driver has crashed... propagate failure
		{Port, {exit_status, _}} ->
			?MODULE ! {driver, crashed},
			exit(crashed);

		
		{Port, {data, Data}} ->
			Decoded = binary_to_term(Data),
			%% Decoded:  {Msgtype, Msg}
			%%            Atom     Tuple
			{Msgtype, Msg} = Decoded,
			M = {Msgtype, Msg, {date(), time(), now()}},
			send_to_reflector(M)
	end,
	loop_drv(Port).


send_to_reflector(M) ->
	Reflector = whereis(reflector),
	send_to_reflector(Reflector, M).


send_to_reflector(undefined, _) ->
	error_logger:warning_msg("manager:send_to_reflector: reflector not found~n"),
	ok;

send_to_reflector(Reflector, M) ->
	%%error_logger:info_msg("manager:send_to_reflector: Msg[~p]~n", [M]),
	Self = self(),
	try Reflector ! {Self, M} of
		
		%% we're echo'ed back the message if everything is OK
		{Self, M} ->
			ok;
		Code ->
			error_logger:warning_msg("manager:send_to_reflector: error sending to reflector, code[~p]", [Code])
	catch
		_:_ -> 
			error_logger:warning_msg("manager:send_to_reflector: error sending~n"),
			ok
	end.
