#pragma semicolon 1

//Required Includes
#include <sourcemod>
#include <multicolors>
#include <extended_logging>
#include <xenforo/xenforo_api>

//New Syntax
#pragma newdecls required

//Defines
#define PLUGIN_NAME     "XenForo API"
#define PLUGIN_AUTHOR   "Keith Warren(Drixevel)"
#define PLUGIN_VERSION  "1.0.1"
#define PLUGIN_DESCRIPTION	"API for Xenforo forum installations."
#define PLUGIN_CONTACT  "http://www.drixevel.com/"

Handle ConVars[5];

bool cv_Enabled; int cv_Logging; char cv_sDatabaseEntry[255]; bool cv_bServerPrints;

Handle hSQLConnection;

Handle hSFW_OnProcessed;
Handle hSFW_OnConnected;

bool bIsProcessed[MAXPLAYERS + 1];
int iUserID[MAXPLAYERS + 1];

bool bLateLoad;

public Plugin myinfo = 
{
	name = PLUGIN_NAME, 
	author = PLUGIN_AUTHOR, 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = PLUGIN_CONTACT
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("XenForo_GrabClientID", Native_GrabClientID);
	CreateNative("XenForo_IsProcessed", Native_IsProcessed);
	CreateNative("XenForo_TExecute", Native_TExecute);
	CreateNative("XenForo_TQuery", Native_TQuery);
	CreateNative("XenForo_LogToFile", Native_Log);
	CreateNative("XenForo_IsConnected", Native_IsConnected);
	
	hSFW_OnProcessed = CreateGlobalForward("XF_OnProcessed", ET_Ignore, Param_Cell);
	hSFW_OnConnected = CreateGlobalForward("XF_OnConnected", ET_Ignore);
	
	RegPluginLibrary("xenforo_api");
	
	bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	XenForo_Log(DEFAULT, "XenForo API is now loading...");
	LoadTranslations("common.phrases");
	
	ConVars[0] = CreateConVar("xenforo_api_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);
	ConVars[1] = CreateConVar("sm_xenforo_api_status", "1", "Status of the plugin: (1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	ConVars[2] = CreateConVar("sm_xenforo_api_logging", "2", "Status for plugin logging: (2 = all, 1 = errors only, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	ConVars[3] = CreateConVar("sm_xenforo_api_database_config", "xenforo", "Name of the config entry to use under database settings: (default: 'xenforo', empty = 'default')", FCVAR_NOTIFY);
	ConVars[4] = CreateConVar("sm_xenforo_api_serverprints", "0", "Print all logs made to server console: (1 = on, 0 = off) (WARNING: WILL SPAM)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	for (int i = 0; i < sizeof(ConVars); i++)
	{
		HookConVarChange(ConVars[i], HandleCvars);
	}
	
	RegConsoleCmd("sm_xfid", ShowID);
	
	AutoExecConfig();
}

public Action ShowID(int client, int args)
{
	ReplyToCommand(client, "Your XenForo ID is %i.", iUserID[client]);
	return Plugin_Handled;
}

public void OnConfigsExecuted()
{
	cv_Enabled = GetConVarBool(ConVars[1]);
	cv_Logging = GetConVarInt(ConVars[2]);
	GetConVarString(ConVars[3], cv_sDatabaseEntry, sizeof(cv_sDatabaseEntry));
	cv_bServerPrints = GetConVarBool(ConVars[4]);
	
	SQL_TConnect(OnSQLConnect, strlen(cv_sDatabaseEntry) != 0 ? cv_sDatabaseEntry : "default");
	
	XenForo_Log(DEFAULT, "XenForo API has been loaded successfully.");
}

public int HandleCvars(Handle cvar, const char[] oldValue, const char[] newValue)
{
	if (StrEqual(oldValue, newValue, true))
	{
		return;
	}
	
	int iNewValue = StringToInt(newValue);
	
	if (cvar == ConVars[0])
	{
		SetConVarString(ConVars[0], PLUGIN_VERSION);
	}
	else if (cvar == ConVars[1])
	{
		cv_Enabled = view_as<bool>(iNewValue);
	}
	else if (cvar == ConVars[2])
	{
		cv_Logging = iNewValue;
	}
	else if (cvar == ConVars[3])
	{
		GetConVarString(ConVars[3], cv_sDatabaseEntry, sizeof(cv_sDatabaseEntry));
	}
	else if (cvar == ConVars[4])
	{
		cv_bServerPrints = view_as<bool>(iNewValue);
	}
}

public int OnSQLConnect(Handle owner, Handle hndl, const char[] sError, any data)
{
	XenForo_Log(DEFAULT, "Connecting to XenForo database...");
	
	if (hndl == null)
	{
		XenForo_Log(ERROR, "SQL ERROR: Error connecting to database - '%s'", sError);
		SetFailState("Error connecting to XenForo database, please verify configurations & connections. (Check Error Logs)");
		return;
	}
	
	hSQLConnection = hndl;
	
	Call_StartForward(hSFW_OnConnected);
	Call_Finish();
	
	XenForo_Log(DEFAULT, "XenForo API has connected to SQL successfully.");
	
	if (bLateLoad)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i))
			{
				OnClientConnected(i);
			}
			
			if (IsClientAuthorized(i))
			{
				char sAuth[64];
				GetClientAuthId(i, AuthId_Steam2, sAuth, sizeof(sAuth));
				OnClientAuthorized(i, sAuth);
			}
		}
		
		bLateLoad = false;
	}
}

public void OnClientConnected(int client)
{
	bIsProcessed[client] = false;
	iUserID[client] = -1;
}

public void OnClientAuthorized(int client, const char[] sSteamID)
{
	if (!cv_Enabled || IsFakeClient(client))
	{
		return;
	}
	
	XenForo_Log(DEFAULT, "Starting process for user %N...", client);
	
	char sCommunityID[64];
	SteamIDToCommunityID(sSteamID, sCommunityID, sizeof(sCommunityID));
	
	char sQuery[256];
	Format(sQuery, sizeof(sQuery), "SELECT user_id FROM xf_user_external_auth WHERE provider = 'steam' AND provider_key = '%s'", sCommunityID);
	SQL_TQuery_XenForo(GrabUserID, sQuery, GetClientUserId(client));
	XenForo_Log(TRACE, "SQL QUERY: OnClientAuthorized - Query: %s", sQuery);
}

public int GrabUserID(Handle owner, Handle hndl, const char[] sError, any data)
{
	int client = GetClientOfUserId(data);
	
	if (!IsClientConnected(client))
	{
		XenForo_Log(ERROR, "Error grabbing User Data: (Client is not Connected)");
		return;
	}
	
	if (!IsClientAuthorized(client))
	{
		XenForo_Log(ERROR, "Error grabbing User Data: (Client is not Authorized)");
		return;
	}
	
	XenForo_Log(DEFAULT, "Retrieving data for %N...", client);
	
	if (hndl == null)
	{
		XenForo_Log(ERROR, "SQL ERROR: Error grabbing User Data for '%N': '%s'", client, sError);
		return;
	}
	
	if (SQL_FetchRow(hndl))
	{
		if (SQL_IsFieldNull(hndl, 0))
		{
			XenForo_Log(ERROR, "Error retrieving User Data: (Field is null)");
			return;
		}
		
		iUserID[client] = SQL_FetchInt(hndl, 0);
		bIsProcessed[client] = true;
		
		Call_StartForward(hSFW_OnProcessed);
		Call_PushCell(client);
		Call_Finish();
		
		XenForo_Log(DEFAULT, "User '%N' has been processed successfully!", client);
	}
	else
	{
		XenForo_Log(ERROR, "Error retrieving User Data: (Row not fetched)");
	}
}

void SQL_TQuery_XenForo(SQLTCallback callback, const char[] sQuery, any data = 0, DBPriority prio = DBPrio_Normal)
{
	if (hSQLConnection != null)
	{
		SQL_TQuery(hSQLConnection, callback, sQuery, data, prio);
		XenForo_Log(TRACE, "SQL Executed: %s", sQuery);
	}
}

public int Native_GrabClientID(Handle plugin, int numParams)
{
	if (!cv_Enabled)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Native is currently disabled.");
	}
	
	int client = GetNativeCell(1);
	
	if (!bIsProcessed[client])
	{
		ThrowNativeError(SP_ERROR_INDEX, "%N is not currently processed.", client);
	}
	
	return iUserID[client];
}

public int Native_IsProcessed(Handle plugin, int numParams)
{
	if (!cv_Enabled)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Native is currently disabled.");
	}
	
	int client = GetNativeCell(1);
	
	return bIsProcessed[client];
}

public int Native_TExecute(Handle plugin, int numParams)
{
	if (!cv_Enabled)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Native is currently disabled.");
	}
	
	int size;
	GetNativeStringLength(1, size);
	
	char[] sQuery = new char[size];
	GetNativeString(1, sQuery, size);
	
	DBPriority prio = GetNativeCell(2);
	
	SQL_TQuery_XenForo(Void_Callback, sQuery, 0, prio);
	XenForo_Log(ERROR, "SQL QUERY: XenForo_TExecute - Query: '%s'", sQuery);
}

public int Void_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		XenForo_Log(ERROR, "Query error by void: '%s'", error);
		return;
	}
}

public int Native_TQuery(Handle plugin, int numParams)
{
	if (!cv_Enabled)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Native is currently disabled.");
	}
	
	int size;
	GetNativeStringLength(2, size);
	
	char[] sQuery = new char[size];
	GetNativeString(2, sQuery, size);
	
	SQLTCallback callback = GetNativeCell(1);
	int data = GetNativeCell(3);
	DBPriority prio = GetNativeCell(4);
	
	Handle hPack = CreateDataPack();
	WritePackCell(hPack, plugin);
	WritePackFunction(hPack, callback);
	WritePackCell(hPack, data);
	
	SQL_TQuery_XenForo(Query_Callback, sQuery, hPack, prio);
	XenForo_Log(ERROR, "SQL QUERY: XenForo_TQuery - Query: '%s'", sQuery);
}

public int Query_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	ResetPack(data);
	Handle plugin = ReadPackCell(data);
	SQLTCallback callback = ReadPackCell(data);
	int pack = ReadPackCell(data);
	CloseHandle(data);
	
	Call_StartFunction(plugin, callback);
	Call_PushCell(owner);
	Call_PushCell(hndl);
	Call_PushString(error);
	Call_PushCell(pack);
	Call_Finish();
}

public int Native_Log(Handle plugin, int numParams)
{
	if (!cv_Enabled || cv_Logging <= 0)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Native is currently disabled.");
	}
	
	ELOG_LEVEL log_level = view_as<ELOG_LEVEL>(GetNativeCell(1));
	
	char sBuffer[1024];
	FormatNativeString(0, 2, 3, sizeof(sBuffer), _, sBuffer);
	XenForo_Log(log_level, sBuffer);
}

public int Native_IsConnected(Handle plugin, int numParams)
{
	if (!cv_Enabled)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Native is currently disabled.");
	}
	
	return hSQLConnection != null;
}

void XenForo_Log(ELOG_LEVEL level = DEFAULT, const char[] format, any ...)
{
	char sBuffer[256];
	VFormat(sBuffer, sizeof(sBuffer), format, 3);
	
	if (cv_bServerPrints)
	{
		PrintToServer(sBuffer);
	}
	
	char sDate[20];
	FormatTime(sDate, sizeof(sDate), "%Y-%m-%d", GetTime());
	
	switch (cv_Logging)
	{
		case 2:Log_File("Xenforo", "xenforo", sDate, level, sBuffer);
		case 1:Log_Error("Xenforo", "xenforo", sDate, sBuffer);
	}
} 