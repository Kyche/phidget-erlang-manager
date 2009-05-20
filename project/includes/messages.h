/**
 * @file   messages.h
 *
 * @date   2009-05-01
 * @author Jean-Lou Dupont
 *
 * \section Messages_Description Description of the Messages on the internal ``litm`` bus
 *
 *
 */

#ifndef MESSAGES_H_
#define MESSAGES_H_

#include "manager.h"

#	define LITM_BUS_MESSAGES 1
#	define LITM_BUS_SYSTEM   2

#	define LITM_ID_MAIN      1
#	define LITM_ID_SIGNALS   2
#	define LITM_ID_SERVER    3
#	define LITM_ID_MANAGER   4
#	define LITM_ID_MESSAGES  5



	/**
	 * Message type field definition
	 */
	typedef int bus_message_type;


	/**
	 * Definition of a _phidget device_
	 *
	 * @param serial serial number
	 * @param name   device name
	 * @param type   device type
	 */
	typedef struct {

		int  serial;
		char name[64];
		char label[64];
		char type[64];
		int  version;

	} phidget_device;

	/**
	 * Device status
	 */
	typedef enum {

		PHIDGET_DEVICE_ACTIVE   = 1,
		PHIDGET_DEVICE_INACTIVE

	} phidget_device_state;

	/**
	 * Digital State type
	 *
	 * \note NOTE: Packing efficiency is not important.
	 *
	 */
	typedef unsigned char phidget_digital_state;

	/**
	 * Digital States definition
	 *
	 */
	typedef enum _digital_states {

		// output
		DIGITAL_STATE_O_T = 1,	// tri-state
		DIGITAL_STATE_O_X,		// don't care
		DIGITAL_STATE_O_I,		// invert
		DIGITAL_STATE_O_0,
		DIGITAL_STATE_O_1,

		// input
		DIGITAL_STATE_I_Q,		// hi-q
		DIGITAL_STATE_I_X,		// don't care
		DIGITAL_STATE_I_I,		// invert
		DIGITAL_STATE_I_0,
		DIGITAL_STATE_I_1,

	} digital_states;


	/**
	 * Reference to a specific phidget device
	 */
	typedef int phidget_device_serial;

			/**
			 * Definition of shutdown message
			 */
			typedef struct {

			} message_shutdown;

			/**
			 * Definition of timer message
			 *
			 * TODO define timer message
			 */
			typedef struct {

			} message_timer;


			/**
			 * Definition of message _phidget_devices_
			 *
			 * @param count the number of devices listed in the message
			 *
			 */
			typedef struct {
				PhidgetDevice *device;
				phidget_device_state state;
			} message_phidget_device;


			/**
			 * Definition of message _phidget_states_
			 */
			typedef struct {
				phidget_device *device;

				int count;
				digital_states (*states)[];
			} message_phidget_digital_states;


			/**
			 * Definition message _phidget_set_states_
			 */
			typedef struct {
				phidget_device *device;

				int count;
				digital_states (*states)[];
			} message_phidget_digital_set_states;


	/**
	 * Message types
	 *
	 * 0 is reserved
	 */
	typedef enum _message_types {

		MESSAGE_SHUTDOWN       = 1,
		MESSAGE_TIMER,

		MESSAGE_PHIDGET_DEVICE,
		MESSAGE_PHIDGET_DIGITAL_STATES,
		MESSAGE_PHIDGET_DIGITAL_SET_STATES

	} message_types;


	/**
	 * Message envelope definition
	 *
	 *
	 * @param type message type
	 * @param serial phidget device serial id
	 * @param message_body message body for the specific message type
	 *
	 */
	typedef struct {

		bus_message_type type;

		union _message_body {

			message_shutdown					ms;
			message_timer						mt;
			message_phidget_device				mpd;
			message_phidget_digital_states      mps;
			message_phidget_digital_set_states  mpss;

		} message_body;

	} bus_message;


	// PROTOTYPES
	// ==========

	void messages_init(void);

#endif /* MESSAGES_H_ */