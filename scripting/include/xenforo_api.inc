#if defined _xenforo_api_included
  #endinput
#endif
#define _xenforo_api_included

#include <extended_logging>

//Natives
/**
 * Returns the ID of the user on the forum.
 *
 * @param client		Client to check.
 * @return		User ID of the given client.
 **/
native XenForo_GrabClientID(client);

/**
 * Returns if the client is processed or not.
 *
 * @param client		Client to check.
 * @return		True if processed, false otherwise.
 **/
native XenForo_IsProcessed(client);

/**
 * Executes a query into XenForo database without a return.
 *
 * @param query			Query to execute.
 * @param prio				Database priority to give.
 * @noreturn
 **/
native XenForo_TExecute(const String:query[], DBPriority:prio=DBPrio_Normal);

/**
 * Queries the database and returns data to a callback.
 *
 * @param callback		Callback to send results to.
 * @param query			Query to execute.
 * @param data				Data to pass through callback.
 * @param prio				Database priority to give.
 * @noreturn
 **/
native XenForo_TQuery(SQLTCallback:callback, const String:query[], any:data = 0, DBPriority:prio = DBPrio_Normal);

/**
 * Log using XenForo's API logging system/rules.
 *
 * @param level			Level to log information to. (DEFAULT, TRACE, DEBUG, INFO, WARN, ERROR)
 * @param log			String or text to log.
 * @param ...			Formatting parameters.
 * @noreturn
 **/
native XenForo_LogToFile(ELOG_LEVEL:level = DEFAULT, const String:log[], any:...);

/**
 * Returns if the plugin is connected successfully.
 *
 * @return		true if connected, false otherwise.
 **/
native XenForo_IsConnected();

//Forwards

/**
 * Called when a user is processed by the plugin and receives a User ID.
 *
 * @param client		Client who has been processed.
 * @noreturn
 **/
forward XF_OnProcessed(client);

/**
 * Called when the plugin connects to the database successfully.
 *
 * @noreturn
 **/
forward XF_OnConnected();

public SharedPlugin:__pl_xenforo_api = 
{
	name = "xenforo_api",
	file = "xenforo_api.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_xenforo_api_SetNTVOptional()
{
	MarkNativeAsOptional("XenForo_GrabClientID");
	MarkNativeAsOptional("XenForo_IsProcessed");
	MarkNativeAsOptional("XenForo_TExecute");
	MarkNativeAsOptional("XenForo_TQuery");
	MarkNativeAsOptional("XenForo_LogToFile");
	MarkNativeAsOptional("XenForo_IsConnected");
}
#endif