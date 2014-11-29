#pragma semicolon 1

//Required Includes
#include <sourcemod>
#include <autoexecconfig>

//API Natives/Forwards
#include <xenforo_api>

#define PLUGIN_NAME     "XenForo API"
#define PLUGIN_AUTHOR   "Keith Warren(Jack of Designs)"
#define PLUGIN_VERSION  "1.0.0"
#define PLUGIN_DESCRIPTION	"API for Xenforo forum installations."
#define PLUGIN_CONTACT  "http://www.jackofdesigns.com/"

new Handle:ConVars[3] = {INVALID_HANDLE, ...};

new bool:cv_Enabled, cv_Logging;

new Handle:hSQLConnection;

new Handle:hSFW_OnProcessed;
new Handle:hSFW_OnConnected;

new bool:bIsProcessed[MAXPLAYERS+1];
new iUserID[MAXPLAYERS+1];

new bool:bLateLoad = false;

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_CONTACT
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
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

public OnPluginStart()
{
	XenForo_Log(DEFAULT, "XenForo API is now loading...");
	LoadTranslations("common.phrases");
	
	AutoExecConfig_SetFile("xenforo_api");

	ConVars[0] = AutoExecConfig_CreateConVar("xenforo_api_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_DONTRECORD);
	ConVars[1] = AutoExecConfig_CreateConVar("sm_xenforo_api_status", "1", "Status of the plugin: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	ConVars[2] = AutoExecConfig_CreateConVar("sm_xenforo_api_logging", "2", "Status for plugin logging: (2 = all, 1 = errors only, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 2.0);
	
	AutoExecConfig_ExecuteFile();

	for (new i = 0; i < sizeof(ConVars); i++)
	{
		HookConVarChange(ConVars[i], HandleCvars);
	}
	
	SQL_TConnect(OnSQLConnect, "xenforo");
	
	AutoExecConfig_CleanFile();
	
	XenForo_Log(DEFAULT, "XenForo API has been loaded successfully.");
}

public OnConfigsExecuted()
{
	cv_Enabled = GetConVarBool(ConVars[1]);
	cv_Logging = GetConVarInt(ConVars[2]);
	
	if (bLateLoad)
	{
		new String:sAuth[64];
		for (new i = 1; i <= MaxClients; i++)
		{				
			if (IsClientConnected(i))
			{
				OnClientConnected(i);
			}
			
			if (IsClientAuthorized(i))
			{
				GetClientAuthString(i, sAuth, sizeof(sAuth));
				OnClientAuthorized(i, sAuth);
			}
		}
	}
}

public HandleCvars (Handle:cvar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue, true)) return;

	new iNewValue = StringToInt(newValue);

	if (cvar == ConVars[0])
	{
		SetConVarString(ConVars[0], PLUGIN_VERSION);
	}
	else if (cvar == ConVars[1])
	{
		cv_Enabled = bool:iNewValue;
	}
	else if (cvar == ConVars[2])
	{
		cv_Logging = iNewValue;
	}
}

public OnClientConnected(client)
{
	bIsProcessed[client] = false;
	iUserID[client] = -1;
}

public OnClientAuthorized(client, const String:sSteamID[])
{
	if (!cv_Enabled || IsFakeClient(client)) return;
	
	new String:sCommunityID[64];
	SteamIDToCommunityID(sSteamID, sCommunityID, sizeof(sCommunityID));
	
	new String:sQuery[256];
	Format(sQuery, sizeof(sQuery), "SELECT user_id FROM xf_user_external_auth WHERE provider = 'steam' AND provider_key = '%s'", sCommunityID);
	SQL_TQuery_XenForo(GrabUserID, sQuery, GetClientUserId(client));
	XenForo_Log(TRACE, "OnClientAuthorized - %s [%s] - Query: %s", sSteamID, sCommunityID, sQuery);
}

public GrabUserID(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		XenForo_Log(ERROR, "Error grabbing UserID: '%s'", error);
		return;
	}
	
	new client = GetClientOfUserId(data);
	
	if (!client)
	{
		return;
	}
	
	if (SQL_FetchRow(hndl) && !SQL_IsFieldNull(hndl, 0))
	{
		iUserID[client] = SQL_FetchInt(hndl, 0);
		bIsProcessed[client] = true;
		XenForo_Log(TRACE, "GrabUserID [%N] - Processed user successfully.", client);
		
		Call_StartForward(hSFW_OnProcessed);
		Call_PushCell(client);
		Call_Finish();
	}
}

public OnSQLConnect(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		new String:sBuffer[64];
		Format(sBuffer, sizeof(sBuffer), "Error connecting to SQL: '%s'", error);
		XenForo_Log(ERROR, sBuffer);
		SetFailState(sBuffer);
		return;
	}
	
	hSQLConnection = hndl;
	
	Call_StartForward(hSFW_OnConnected);
	Call_Finish();
	
	XenForo_Log(DEFAULT, "XenForo API has connected to SQL successfully.");
}

SQL_TQuery_XenForo(SQLTCallback:callback, const String:query[], any:data = 0, DBPriority:prio=DBPrio_Normal)
{
	if (hSQLConnection != INVALID_HANDLE)
	{
		SQL_TQuery(hSQLConnection, callback, query, data, prio);
	}
}

SteamIDToCommunityID(const String:sSteamID[], String:sCommunityID[], size)
{
    new String:sBuffer[3][32];
    ExplodeString(sSteamID, ":", sBuffer, 3, 32);
    new accountID = StringToInt(sBuffer[2]) * 2 + StringToInt(sBuffer[1]);

    IntToString((accountID + 60265728), sCommunityID, size);

    if (accountID >= 39734272)
    {
        strcopy(sCommunityID, size, sCommunityID[1]);
        Format(sCommunityID, size, "765611980%s", sCommunityID);
    }
    else
    {
        Format(sCommunityID, size, "765611979%s", sCommunityID);
    }
}

public Native_GrabClientID(Handle:plugin, numParams)
{
	if (!cv_Enabled) ThrowNativeError(SP_ERROR_INDEX, "Native is currently disabled.");

	new client = GetNativeCell(1);
	
	if (!bIsProcessed[client])
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is not currently processed.", client);
	}
	
	return iUserID[client];
}

public Native_IsProcessed(Handle:plugin, numParams)
{
	if (!cv_Enabled) ThrowNativeError(SP_ERROR_INDEX, "Native is currently disabled.");

	new client = GetNativeCell(1);
	
	return bIsProcessed[client];
}

public Native_TExecute(Handle:plugin, numParams)
{
	if (!cv_Enabled) ThrowNativeError(SP_ERROR_INDEX, "Native is currently disabled.");
	
	new size;
	GetNativeStringLength(1, size);
	
	new String:sQuery[size];
	GetNativeString(1, sQuery, size);
	
	new DBPriority:prio = DBPriority:GetNativeCell(2);
	
	SQL_TQuery_XenForo(Void_Callback, sQuery, 0, prio);
}

public Void_Callback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		XenForo_Log(ERROR, "Query error by void: '%s'", error);
	}
}

public Native_TQuery(Handle:plugin, numParams)
{
	if (!cv_Enabled) ThrowNativeError(SP_ERROR_INDEX, "Native is currently disabled.");
	
	new size;
	GetNativeStringLength(2, size);
	
	new String:sQuery[size];
	GetNativeString(2, sQuery, size);
	
	new SQLTCallback:callback = SQLTCallback:GetNativeCell(1);
	new data = GetNativeCell(3);
	new DBPriority:prio = DBPriority:GetNativeCell(4);
	
	new Handle:hPack = CreateDataPack();
	WritePackCell(hPack, _:plugin);
	WritePackCell(hPack, _:callback);
	WritePackCell(hPack, data);
	
	SQL_TQuery_XenForo(Query_Callback, sQuery, hPack, prio);
}

public Query_Callback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	ResetPack(data);
	new Handle:plugin = Handle:ReadPackCell(data);
	new SQLTCallback:callback = SQLTCallback:ReadPackCell(data);
	new pack = ReadPackCell(data);
	CloseHandle(data);
	
	Call_StartFunction(plugin, callback);
	Call_PushCell(owner);
	Call_PushCell(hndl);
	Call_PushString(error);
	Call_PushCell(pack);
	Call_Finish();
}

public Native_Log(Handle:plugin, numParams)
{
	if (!cv_Enabled || cv_Logging <= 0) ThrowNativeError(SP_ERROR_INDEX, "Native is currently disabled.");
	
	new ELOG_LEVEL:log_level = ELOG_LEVEL:GetNativeCell(1);
	
	new String:sBuffer[1024];
	FormatNativeString(0, 2, 3, sizeof(sBuffer), _, sBuffer);
	XenForo_Log(log_level, sBuffer);
}

stock XenForo_Log(ELOG_LEVEL:level = DEFAULT, const String:format[], any:...)
{
	new String:sBuffer[256];
	VFormat(sBuffer, sizeof(sBuffer), format, 3);
	//PrintToServer(sBuffer);
	
	new String:sDate[20];
	FormatTime(sDate, sizeof(sDate), "%Y-%m-%d", GetTime());
		
	switch (cv_Logging)
	{
		case 2: Log_File("Xenforo", "xenforo", sDate, level, sBuffer);
		case 1: Log_Error("Xenforo", "xenforo", sDate, sBuffer);
	}
}

public Native_IsConnected(Handle:plugin, numParams)
{
	if (!cv_Enabled) ThrowNativeError(SP_ERROR_INDEX, "Native is currently disabled.");
	
	if (hSQLConnection != INVALID_HANDLE)
	{
		return true;
	}
	return false;
}