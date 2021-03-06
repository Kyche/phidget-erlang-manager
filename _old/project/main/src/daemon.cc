/**
 * @file daemon.c
 *
 * @date   2009-04-22
 * @author Jean-Lou Dupont
 */

#include "daemon.h"
#include "helpers.h"

#define COMMAND_INVALID -1
#define COMMAND_STOP     0
#define COMMAND_START    1


// PRIVATE PROTOTYPES
// ==================
DaemonErrorCode __daemon_verify_match(const char *name, pid_t pid);
DaemonErrorCode __daemon_get_pid_from_file(const char *name, pid_t *pid);
DaemonErrorCode __daemon_handle_stop(const char *name);
DaemonErrorCode __daemon_handle_start(const char *name);
DaemonErrorCode __daemon_write_pid_file(const char *name);
int   __daemon_translate_command(const char *cmd);
void  __daemon_delete_pid_file(const char *name);
char *__daemon_construct_pid_filename(const char *name);



// -------------------------------------------------------
//
// PUBLIC
//


/**
 *  Handles the 'start / stop' commands
 *  @param name: the daemon's name
 *  @param cmd:  the command, either 'start' or 'stop'
 *
 */
DaemonErrorCode daemon_handle_command(const char *name, char *cmd) {

	DEBUG_MSG("DEBUG: daemon_handle_command: BEGIN\n");

	int command = __daemon_translate_command(cmd);
	DaemonErrorCode command_result;

	switch(command) {
	case COMMAND_STOP:
		command_result = __daemon_handle_stop(name);
		break;
	case COMMAND_START:
		command_result = __daemon_handle_start(name);
		break;
	default:
		return DAEMON_CODE_INVALID_COMMAND;
	}

	DEBUG_MSG("DEBUG: daemon_handle_command: END\n");

	return command_result;
}// daemon_handle_command

/**
 * Returns 0 if the command is valid
 */
int daemon_validate_command(const char *command) {

	int result = __daemon_translate_command(command);

	return !(result != COMMAND_INVALID);
}

// --------------------------------------------------------
//
// PRIVATE
//

/**
 * Handles the ``stop`` command
 *
 *  We need to determine if the daemon is running;
 *  this is done by inspecting the PID file as well as
 *  the /proc/$pid/cmdline that started the process pointed
 *  to in /var/run/$name
 *
 */
DaemonErrorCode __daemon_handle_stop(const char *name) {

	DEBUG_MSG("DEBUG: __daemon_handle_stop: BEGIN\n");

	DaemonErrorCode result;
	pid_t pid;

	// GET the PID from /var/run
	result =__daemon_get_pid_from_file(name, &pid);
	if (DAEMON_CODE_OK != result) {
		return result;
	}

	// whatever happens, we need to get rid
	//  of stale PID file
	__daemon_delete_pid_file(name);

	// COMPARE with the command-line that should
	//  have started the daemon
	result = __daemon_verify_match(name, pid);
	if (DAEMON_CODE_OK != result) {
		return result;
	}

	// SEND the kill signal...
	int kill_result = kill( pid, SIGTERM);

	if (0!=kill_result) {
		return DAEMON_CODE_KILL_FAILED;
	}

	doLog(LOG_INFO, "daemon stopped, pid[%u]", pid);

	DEBUG_MSG("DEBUG: __daemon_handle_stop: END\n");

	return DAEMON_CODE_EXITING;
} // STOP

/**
 * Handles the ``start`` command
 *
 *  The daemon must not already exist (!)
 */
DaemonErrorCode __daemon_handle_start(const char *name) {

	DEBUG_MSG("DEBUG: __daemon_handle_start: BEGIN\n");

	DaemonErrorCode result;
	pid_t pid;

	// GET the PID from /var/run
	result =__daemon_get_pid_from_file(name, &pid);
	if (DAEMON_CODE_OK == result) {

		// we got a PID... is the daemon really running?
		result = __daemon_verify_match(name, pid);
		if (DAEMON_CODE_OK == result) {
			return DAEMON_CODE_DAEMON_EXIST;
		}

		//get rid of stale PID file
		__daemon_delete_pid_file(name);
		DEBUG_MSG("DEBUG: __daemon_handle_start: got rid of stale PID file\n");
	}

	DEBUG_MSG("DEBUG: __daemon_handle_start: BEFORE daemon()\n");
	// DEMON START
	daemon(0,0);

	result = __daemon_write_pid_file(name);

	doLog(LOG_INFO, "daemon started" );

	return result;
}// START

/**
 * Writes the PID file for the current daemon
 */
DaemonErrorCode __daemon_write_pid_file(const char *name) {

	DEBUG_MSG("DEBUG: __daemon_write_pid_file: BEGIN\n");

	char *filename;
	pid_t pid = getpid();
	FILE *file;
	char write_buffer[32];

	filename = __daemon_construct_pid_filename(name);

	file = fopen(filename, "w");
	if (NULL==file) {
		return DAEMON_CODE_WRITING_PID_FILE;
	}

	free(filename);

	snprintf(write_buffer, 31, "%u", pid);

	if (EOF==fputs((const char *)write_buffer, file)) {
		fclose(file);
		return DAEMON_CODE_WRITING_PID_FILE;
	}
	fclose(file);

	DEBUG_MSG("DEBUG: __daemon_write_pid_file: END\n");

	return DAEMON_CODE_OK;
}// __daemon_write_pid_file


void __daemon_delete_pid_file(const char *name) {

	DEBUG_MSG("DEBUG: __daemon_delete_pid_file: BEGIN\n");

	char *filename;

	filename = __daemon_construct_pid_filename(name);

	remove(filename);
	free(filename);

	DEBUG_MSG("DEBUG: __daemon_delete_pid_file: END\n");

}// __daemon_delete_pid_file

/**
 * Translates a string command to an integer
 *  whilst verifying the validity of the said command.
 *
 */
int __daemon_translate_command(const char *cmd) {

	if (NULL==cmd) {
		return COMMAND_INVALID;
	}

	if (0==strncasecmp(cmd, "start", sizeof("start"))) {
		return COMMAND_START;
	}

	if (0==strncasecmp(cmd, "stop", sizeof("stop"))) {
		return COMMAND_STOP;
	}

	return COMMAND_INVALID;
}// __daemon_translate_command

/**
 * Returns 1 if TRUE
 */
int daemon_is_start_command(const char *command) {

	return __daemon_translate_command(command) == COMMAND_START;
}

/**
 * Retrieves the PID from the filesystem /var/run/$name
 *  Returns <0 on error
 */
DaemonErrorCode __daemon_get_pid_from_file(const char *name, pid_t *pid) {

	DEBUG_MSG("DEBUG: __daemon_get_pid_from_file: BEGIN\n");

	char *filename;
	char read_buffer[32];
	FILE *file;

	if (NULL==name) {
		return DAEMON_CODE_INVALID_NAME;
	}

	filename = __daemon_construct_pid_filename(name);

	DEBUG_MSG("DEBUG: __daemon_get_pid_from_file: OPENING file\n");
	file = fopen( filename, "r" );
	if (NULL==file) {
		return DAEMON_CODE_READING_PID_FILE;
	}

	DEBUG_MSG("DEBUG: __daemon_get_pid_from_file: READING file\n");
	char *result = \
		fgets(read_buffer, sizeof(read_buffer)*sizeof(char), file );

	fclose( file );

	DEBUG_MSG("DEBUG: __daemon_get_pid_from_file: FREEing filename\n");
	free(filename);

	if (result!=read_buffer) {
		return DAEMON_CODE_READING_PID_FILE;
	}

	DEBUG_MSG("DEBUG: __daemon_get_pid_from_file: CONVERTING pid\n");
	pid_t _pid = (pid_t) atoi( read_buffer );
	if (0==_pid) {
		return DAEMON_CODE_INVALID_PID;
	}

	DEBUG_MSG("DEBUG: __daemon_get_pid_from_file: RETURNING pid[%u]\n", _pid);
	*pid = _pid;

	DEBUG_MSG("DEBUG: __daemon_get_pid_from_file: END\n");

	return DAEMON_CODE_OK;
}// daemon_get_pid_from_file


/**
 * Constructs the PID filename
 *  The client of this function is responsible for
 *  freeing the memory buffer.
 */
char *__daemon_construct_pid_filename(const char *name) {

	DEBUG_MSG("DEBUG: __daemon_construct_pid_filename: BEGIN\n");

	char *filename = (char *) malloc(1024*sizeof(char));

	snprintf(filename, 1024*sizeof(char), "/var/run/%s", name);

	DEBUG_MSG("DEBUG: __daemon_construct_pid_filename: END\n");

	return filename;
}//__daemon_construct_pid_filename


/**
 * Verifies that the process of PID $pid matches
 *  the command line $name.
 *
 *  If there isn't a match, it is probably because:
 *  1) the daemon is non-existent / killed
 *  2) the command-line that started the daemon isn't what
 *     it is expected... renamed probably?
 *
 *  This function reads the command-line string found
 *  in /proc/$pid/cmdline and matches it with $name
 *
 */
DaemonErrorCode __daemon_verify_match(const char *name, pid_t pid) {

	DEBUG_MSG("DEBUG: __daemon_verify_match: BEGIN\n");

	char filename[1024];
	char read_buffer[1024];
	FILE *file;
	int  rc;
	regex_t * myregex = (regex_t *) calloc(1, sizeof(regex_t));


	if (NULL==name) {
		return DAEMON_CODE_INVALID_NAME;
	}

	if (0==pid) {
		return DAEMON_CODE_INVALID_PID;
	}

	snprintf(filename, sizeof(filename)*sizeof(char), "/proc/%u/cmdline", pid);
	DEBUG_LOG(LOG_DEBUG, "process cmdline filename [%s]", filename);

	file = fopen( filename, "r" );
	if (NULL==file) {
		return DAEMON_CODE_READING_PROC_CMDLINE;
	}

	char *result = \
		fgets(read_buffer, sizeof(read_buffer)*sizeof(char), file );

	fclose( file );

	if (result!=read_buffer) {
		return DAEMON_CODE_READING_PROC_CMDLINE;
	}

	// perform sub-string match test
	rc = regcomp( myregex, name, REG_EXTENDED | REG_NOSUB );
	if (0!=rc) {
		// if we have trouble compiling the regex,
		//  then the daemon name is not appropriate;
		//  anyhow, the daemon name SHOULD be simple!
		return DAEMON_CODE_INVALID_NAME;
	}

	rc = regexec( myregex, read_buffer, 0, 0, 0 );
	if (0!=rc) {
		return DAEMON_CODE_PROC_CMDLINE_NOMATCH;
	}

	DEBUG_MSG("DEBUG: __daemon_verify_match: END\n");

	return DAEMON_CODE_OK;
}// daemon_verify_match

