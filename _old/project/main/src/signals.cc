/**
 * @file signals.c
 *
 * Signal handling for the whole process
 *
 *  @date   2009-04-22
 *  @author Jean-Lou Dupont
 *
 *
 * This module confines all signals from the process
 * to the handler thread: signals are then dispatched
 * to all interested subscribers through <b>litm</b>.
 *
 */

#include <stdlib.h>
#include "signals.h"
#include "helpers.h"
#include "messages.h"
#include <litm.h>
#include "utils.h"


// PRIVATE
pthread_t		__signal_thread;

// PRIVATE PROTOTYPES
void *__signals_handler_thread(void* arg);


/**
 * Init the module
 */
void signals_init(void) {

	DEBUG_MSG("DEBUG: signals_init: BEGIN\n");

	// Confine all process signals
	//  to one thread: easier management

	/* block all signals */
	sigset_t 	signal_set;

	sigfillset( &signal_set );
	pthread_sigmask( SIG_BLOCK, &signal_set, NULL );

	/* create the signal handling thread */
	pthread_create( &__signal_thread, NULL, __signals_handler_thread, NULL );

	DEBUG_MSG("DEBUG: signals_init: END\n");

}// signal_init



// -----------------------------------------------------------------------------
//
// PRIVATE
//


/**
 * Signal Handler for the whole process
 */
void *__signals_handler_thread(void* params) {

	litm_connection *conn = NULL;
	litm_code code;

	// TODO LITM connect error: is there a better way to handle this??
	code = litm_connect_ex( &conn, LITM_ID_SIGNALS);
	if (LITM_CODE_OK != code)
		DEBUG_LOG(LOG_ERR, "cannot connect to LITM");

	static bus_message shutdown_message;
	static bus_message alarm_message;

	sigset_t signal_set;
	int sig, __exit=0;

	for(;;) {
		/* wait for any and all signals */
		sigfillset( &signal_set );
		sigwait( &signal_set, &sig );

		switch( sig ) {

		case SIGTERM:
			DEBUG_LOG(LOG_DEBUG, "signals: received SIGTERM");
			// void_cleaner in utils.c
			if (NULL!=conn)
				litm_send( conn, LITM_BUS_SYSTEM, &shutdown_message, &void_cleaner, LITM_MESSAGE_TYPE_SHUTDOWN );
			__exit = 1;
			break;

		case SIGQUIT:
			DEBUG_LOG(LOG_DEBUG, "signals: received SIGQUIT");
			break;

		 case SIGINT:
			DEBUG_LOG(LOG_DEBUG, "signals: received SIGINT");
			break;

		 case SIGVTALRM:
				// this won't get triggered as setitimer cannot
				// be used in conjunction with the sleep/usleep functions.
				// Since phidget21 already relies on usleep/sleep, we can't
				// mess around with alarms, unfortunately.
			 DEBUG_LOG(LOG_DEBUG, "signals: received SIGVTALRM");
				if (NULL!=conn)
					litm_send( conn, LITM_BUS_SYSTEM, &alarm_message, &void_cleaner, LITM_MESSAGE_TYPE_TIMER );
			 break;

		 case SIGALRM:
			DEBUG_LOG(LOG_DEBUG, "signals: received SIGALRM");
			break;

		default:
			DEBUG_LOG(LOG_DEBUG, "signals: unsupported signal, sig[%i]", sig);
			break;
		}

		if (1==__exit) {
			break;
		}
	}

	//litm_wait_shutdown();

	DEBUG_LOG( LOG_INFO, "signals: END thread" );

	return (void*)0;
}//signal_handler_thread

