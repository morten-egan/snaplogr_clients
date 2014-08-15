create or replace package snaplogr
authid current_user

as

	/** This package is an API to the snaplogr service at snaplogr.com
	* @author Morten Egan
	* @version 0.0.1
	* @project snaplogr_client
	*/
	p_version		varchar2(50) := '0.0.1';

	/** Setup session for snaplogr
	* @author Morten Egan
	* @param snaplogr_user The username for snaplogr
	*/
	procedure setup (
		snaplogr_user						in				varchar2
		, snaplogr_pass						in				varchar2
	);

	/** Simple string logging
	* @author Morten Egan
	* @param logstring The simple string to ship to snaplogr
	*/
	procedure log (
		logstring						in				varchar2
	);

	/** Start a snaplogr runstat
	* @author Morten Egan
	* @param parm_name A description of the parameter
	*/
	procedure sr;

	/** Middle point of snaplogr runstat
	* @author Morten Egan
	* @param parm_name A description of the parameter
	*/
	procedure mr;

	/** End a snaplogr runstat
	* @author Morten Egan
	* @param stop_val The min diff between vals
	*/
	procedure er (
		stop_val						in				number default 500
	);

	/** Add a message to a list of messages
	* @author Morten Egan
	* @param list_name The name of the list to add a message to. List created if it does not exist
	* @param logstring The simple string to ship to the list
	*/
	procedure addtolist (
		list_name						in				varchar2
		, logstring						in				varchar2
	);

	/** Send a complete list of log entries to snaplog
	* @author Morten Egan
	* @param list_name The list to snaplog
	*/
	procedure loglist (
		list_name						in				varchar2
	);

end snaplogr;
/