#pragma semicolon 1

//Required Includes
#include <sourcemod>
#include <multicolors>
#include <extended_logging>
#include <xenforo/xenforo_api>
#include <xenforo/xenforo_credits>

//New Syntax
#pragma newdecls required

//Defines
#define PLUGIN_NAME     "XenForo Credits Plugin"
#define PLUGIN_AUTHOR   "Keith Warren(Drixevel)"
#define PLUGIN_VERSION  "1.0.1"
#define PLUGIN_DESCRIPTION	"Retrieves credits from XenForo API of XenForo Installation."
#define PLUGIN_CONTACT  "http://www.drixevel.com/"

bool bLateLoad;

int iCredits[MAXPLAYERS + 1];

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
	CreateNative("XenForo_GrabCredits", Native_GrabCredits);
	CreateNative("XenForo_GiveCredits", Native_GiveCredits);
	CreateNative("XenForo_DeductCredits", Native_DeductCredits);
	
	RegPluginLibrary("xenforo_credits");
	
	bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	float fTime = GetRandomFloat(60.0, 180.0);
	CreateTimer(fTime, GiveCredits_Timed, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	RegConsoleCmd("sm_creditsamount", CreditsAmount);
}

public void OnConfigsExecuted()
{
	if (bLateLoad)
	{
		if (XenForo_IsConnected())
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (XenForo_IsProcessed(i))
				{
					XF_OnProcessed(i);
				}
			}
		}
		
		bLateLoad = false;
	}
}

public Action CreditsAmount(int client, int args)
{
	if (!IsClientInGame(client))
	{
		CReplyToCommand(client, "%t", "Command is in-game only");
		return Plugin_Handled;
	}
	
	if (!XenForo_IsProcessed(client))
	{
		CReplyToCommand(client, "You are currently not processed, please try again later.");
		return Plugin_Handled;
	}
	
	CPrintToChat(client, "Your current amount of credits is %i.", iCredits[client]);
	
	return Plugin_Handled;
}

public Action GiveCredits_Timed(Handle hTimer)
{
	int amount = GetRandomInt(10, 50);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && XenForo_IsProcessed(i))
		{
			GiveClientCredits(i, amount);
		}
	}
}

public void OnClientConnected(int client)
{
	iCredits[client] = 0;
}

public void OnClientDisconnect(int client)
{
	iCredits[client] = 0;
}

public void XF_OnProcessed(int client)
{
	int ID = XenForo_GrabClientID(client);
	
	char sQuery[1024];
	Format(sQuery, sizeof(sQuery), "SELECT credits FROM xf_user WHERE user_id = '%i';", ID);
	XenForo_TQuery(RetrieveCredits, sQuery, GetClientUserId(client));
	XenForo_LogToFile(TRACE, "SQL QUERY: XF_OnProcessed - Query: %s", sQuery);
}

public int RetrieveCredits(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		XenForo_LogToFile(ERROR, "Error grabbing credits for UserID: '%s'", error);
		return;
	}
	
	int client = GetClientOfUserId(data);
	
	if (client < 0 || !IsClientInGame(client))
	{
		return;
	}
	
	if (SQL_FetchRow(hndl) && !SQL_IsFieldNull(hndl, 0))
	{
		iCredits[client] = SQL_FetchInt(hndl, 0);
		XenForo_LogToFile(TRACE, "Credits pulled from SQL query for %N: %i", client, iCredits[client]);
	}
}

public int Native_GrabCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (!XenForo_IsProcessed(client))
	{
		ThrowNativeError(SP_ERROR_INDEX, "%N is not currently processed.", client);
	}
	
	return iCredits[client];
}

public int Native_GiveCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int amount = GetNativeCell(2);
	
	if (!XenForo_IsProcessed(client))
	{
		ThrowNativeError(SP_ERROR_INDEX, "%N is not currently processed.", client);
	}
	
	GiveClientCredits(client, amount);
}

void GiveClientCredits(int client, int amount)
{
	int credits = iCredits[client];
	iCredits[client] = credits + amount;
	int clientID = XenForo_GrabClientID(client);
	
	char sQuery[1024];
	Format(sQuery, sizeof(sQuery), "UPDATE xf_user SET credits = '%i' WHERE user_id = '%i';", iCredits[client], clientID);
	XenForo_TQuery(GiveCredits, sQuery, GetClientUserId(client));
	XenForo_LogToFile(TRACE, "SQL Query: GiveClientCredits - Query: '%s'", sQuery);
}
public int GiveCredits(Handle owner, Handle hndl, const char[] error, any data)
{
	int client = GetClientOfUserId(data);
	
	if (hndl == null)
	{
		XenForo_LogToFile(ERROR, "Error inserting credits value into database: '%s'", error);
		CPrintToChat(client, "Error updating your credits, please contact an administrator.");
		return;
	}
	
	if (client < 0 || !IsClientInGame(client))
	{
		return;
	}
	
	CPrintToChat(client, "You have been given credits. Your credits count is now at %i.", iCredits[client]);
}

public int Native_DeductCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int amount = GetNativeCell(2);
	
	if (!XenForo_IsProcessed(client))
	{
		ThrowNativeError(SP_ERROR_INDEX, "%N is not currently processed.", client);
	}
	
	DeductClientCredits(client, amount);
}

void DeductClientCredits(int client, int amount)
{
	int credits = iCredits[client];
	iCredits[client] = credits - amount;
	int clientID = XenForo_GrabClientID(client);
	
	char sQuery[1024];
	Format(sQuery, sizeof(sQuery), "UPDATE xf_user SET credits = '%i' WHERE user_id = '%i';", iCredits[client], clientID);
	XenForo_TQuery(DeductCredits, sQuery, GetClientUserId(client));
	XenForo_LogToFile(TRACE, "SQL Query: DeductClientCredits - Query: '%s'", sQuery);
}

public int DeductCredits(Handle owner, Handle hndl, const char[] error, any data)
{
	int client = GetClientOfUserId(data);
	
	if (hndl == null)
	{
		XenForo_LogToFile(ERROR, "Error inserting credits value into database: '%s'", error);
		CPrintToChat(client, "Error updating your credits, please contact an administrator.");
		return;
	}
	
	if (client < 0 || !IsClientInGame(client))
	{
		return;
	}
	
	CPrintToChat(client, "You have been deducted credits. Your credits count is now at %i.", iCredits[client]);
} 