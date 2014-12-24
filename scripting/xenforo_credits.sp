#pragma semicolon 1

//Required Includes
#include <sourcemod>
#include <morecolors>

//API Natives/Forwards
#include <xenforo_api>
#include <xenforo_credits>

#define PLUGIN_NAME     "XenForo Credits Plugin"
#define PLUGIN_AUTHOR   "Keith Warren(Jack of Designs)"
#define PLUGIN_VERSION  "1.0.1"
#define PLUGIN_DESCRIPTION	"Retrieves credits from XenForo API of XenForo Installation."
#define PLUGIN_CONTACT  "http://www.jackofdesigns.com/"

new bool:bLateLoad;

new iCredits[MAXPLAYERS+1];

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
	CreateNative("XenForo_GrabCredits", Native_GrabCredits);
	CreateNative("XenForo_GiveCredits", Native_GiveCredits);
	CreateNative("XenForo_DeductCredits", Native_DeductCredits);
	
	RegPluginLibrary("xenforo_credits");
	
	bLateLoad = late;
	return APLRes_Success;
}

public OnPluginStart()
{
	new Float:fTime = GetRandomFloat(60.0, 180.0);
	CreateTimer(fTime, GiveCredits_Timed, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public OnConfigsExecuted()
{
	if (bLateLoad && XenForo_IsConnected())
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (XenForo_IsProcessed(i))
			{
				XF_OnProcessed(i);
			}
		}
	}
}

public Action:GiveCredits_Timed(Handle:hTimer)
{
	new amount = GetRandomInt(10, 50);
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || XenForo_IsProcessed(i)) continue;
		
		GiveClientCredits(i, amount);
	}
}

public OnClientConnected(client)
{
	iCredits[client] = 0;
}

public OnClientDisconnect(client)
{
	iCredits[client] = 0;
}

public XF_OnProcessed(client)
{
	new clientID = XenForo_GrabClientID(client);
	
	new String:sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "SELECT credits FROM xf_user WHERE user_id = '%i';", clientID);	
	XenForo_TQuery(RetrieveCredits, sQuery, GetClientUserId(client));
	XenForo_LogToFile(TRACE, "SQL QUERY: XF_OnProcessed - Query: %s", sQuery);
}

public RetrieveCredits(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		XenForo_LogToFile(ERROR, "Error grabbing credits for UserID: '%s'", error);
		return;
	}
	
	new client = GetClientOfUserId(data);
	
	if (!client || !IsClientInGame(client))
	{
		return;
	}
	
	if (SQL_FetchRow(hndl) && !SQL_IsFieldNull(hndl, 0))
	{
		iCredits[client] = SQL_FetchInt(hndl, 0);
	}
}

public Native_GrabCredits(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	if (!XenForo_IsProcessed(client))
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is not currently processed.", client);
	}
	
	return iCredits[client];
}

public Native_GiveCredits(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new amount = GetNativeCell(2);
	
	if (!XenForo_IsProcessed(client))
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is not currently processed.", client);
	}
	
	GiveClientCredits(client, amount);
}

GiveClientCredits(client, amount)
{
	new credits = iCredits[client];
	iCredits[client] = credits + amount;
	new clientID = XenForo_GrabClientID(client);
	
	new String:sQuery[1024];
	Format(sQuery, sizeof(sQuery), "UPDATE xf_user SET credits = '%i' WHERE user_id = '%i';", iCredits[client], clientID);
	XenForo_TQuery(GiveCredits, sQuery, GetClientUserId(client));
	XenForo_LogToFile(ERROR, "SQL Query: GiveClientCredits - Query: '%s'", sQuery);
}
public GiveCredits(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	new client = GetClientOfUserId(data);
	
	if (hndl == INVALID_HANDLE)
	{
		XenForo_LogToFile(ERROR, "Error inserting credits value into database: '%s'", error);
		CPrintToChat(client, "Error updating your credits, please contact an administrator.");
		return;
	}
		
	if (!client || !IsClientInGame(client))
	{
		return;
	}

	CPrintToChat(client, "You have been given credits. Your credits count is now at %i.", iCredits[client]);
}

public Native_DeductCredits(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new amount = GetNativeCell(2);
	
	if (!XenForo_IsProcessed(client))
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is not currently processed.", client);
	}
	
	DeductClientCredits(client, amount);
}

DeductClientCredits(client, amount)
{
	new credits = iCredits[client];
	iCredits[client] = credits - amount;
	new clientID = XenForo_GrabClientID(client);
	
	new String:sQuery[1024];
	Format(sQuery, sizeof(sQuery), "UPDATE xf_user SET credits = '%i' WHERE user_id = '%i';", iCredits[client], clientID);
	XenForo_TQuery(DeductCredits, sQuery, GetClientUserId(client));
	XenForo_LogToFile(ERROR, "SQL Query: DeductClientCredits - Query: '%s'", sQuery);
}
public DeductCredits(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	new client = GetClientOfUserId(data);
	
	if (hndl == INVALID_HANDLE)
	{
		XenForo_LogToFile(ERROR, "Error inserting credits value into database: '%s'", error);
		CPrintToChat(client, "Error updating your credits, please contact an administrator.");
		return;
	}
		
	if (!client || !IsClientInGame(client))
	{
		return;
	}

	CPrintToChat(client, "You have been deducted credits. Your credits count is now at %i.", iCredits[client]);
}