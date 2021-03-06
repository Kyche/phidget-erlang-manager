/**
 * @file device.cc
 *
 * @date 2009-06-04
 * @author Jean-Lou Dupont
 */
#include "base.h"

phDevice::phDevice(CPhidgetHandle _phid){
	//DEBUG_LOG(LOG_INFO, "phDevice::phDevice");

	phid  = _phid;
	type  = NULL;
	name  = NULL;
	label = NULL;
}//

phDevice::~phDevice() {
	//DEBUG_LOG(LOG_INFO, "phDevice::~phDevice");

	if (NULL!=type)
		free(type);

	if (NULL!=name)
		free(name);

	if (NULL!=label)
		free(label);
}//

void
phDevice::init(void) {

	//DEBUG_LOG(LOG_INFO, "phDevice::init() BEGIN");

	const char *_type, *_name, *_label;

	CPhidget_getSerialNumber(phid, &serial);
	CPhidget_getDeviceVersion(phid, &version);
	CPhidget_getDeviceType(phid, (const char **) &_type);
	CPhidget_getDeviceName(phid, (const char **) &_name);
	CPhidget_getDeviceLabel(phid, (const char **)&_label);

	//perform copies
	size_t sz_char = sizeof(char);

	size_t sz_type  = strlen( _type )  + sz_char;
	size_t sz_name  = strlen( _name )  + sz_char;
	size_t sz_label = strlen( _label ) + sz_char;

	type  = (char *) malloc( sz_type  * sizeof(char) );
	name  = (char *) malloc( sz_name  * sizeof(char) );
	label = (char *) malloc( sz_label * sizeof(char) );

	strncpy( type,  _type,  sz_type  );
	strncpy( name,  _name,  sz_name  );
	strncpy( label, _label, sz_label );

	//DEBUG_LOG(LOG_INFO, "phDevice::init() END");
}//
