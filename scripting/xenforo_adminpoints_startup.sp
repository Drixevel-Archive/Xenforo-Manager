#pragma semicolon 1

//Required Includes
#include <sourcemod>
#include <multicolors>
#include <extended_logging>
#include <xenforo/xenforo_api>

//New Syntax
#pragma newdecls required

//Defines

//Globals
char sQuery_GrantAdminPoints[] = "UPDATE xf_user_field_value SET field_value = field_value + 2 WHERE user_id = '%i' AND field_id = 'adminpoints';";

int Start = -1;

public Plugin myinfo = 
{
	name = "XenForo API", 
	author = "Keith Warren(Drixevel)", 
	description = "Grants admins points based on actions in the servers.", 
	version = "1.0.0", 
	url = "http://www.drixevel.com/"
};

public void OnPluginStart()
{
	CreateTimer(60.0, GrantAdminPoints);
}

public void XF_OnProcessed(int client)
{
	if (Start == -1 && CheckCommandAccess(client, "", ADMFLAG_GENERIC))
	{
		if (GetRealClientCount() < 2)
		{
			Start = client;
		}
	}
}

public void OnClientDisconnect(int client)
{
	if (client == Start)
	{
		Start = -1;
	}
}

public Action GrantAdminPoints(Handle hTimer)
{
	int client = GetClientOfUserId(Start);
	
	if (Start != -1 && GetRealClientCount() >= 12)
	{
		char sQuery[MAX_QUERY_SIZE];
		Format(sQuery, sizeof(sQuery), sQuery_GrantAdminPoints, XenForo_GrabClientID(client));
		XenForo_TQuery(AddPoints, sQuery);
	}
	
	return Plugin_Continue;
}

public void AddPoints(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == INVALID_HANDLE)
	{
		XenForo_LogToFile(DEFAULT, "Error setting Admin Points: '%s'", error);
		return;
	}
	
	int client = GetClientOfUserId(Start);
	
	if (client > 0)
	{
		PrintToChat(client, "You have received 2 admin points!");
	}
}

int GetRealClientCount(bool inGameOnly = true)
{
	int clients = 0;
	
	for (int i = 0; i < GetMaxClients(); i++)
	{
		if ((inGameOnly ? IsClientInGame(i) : IsClientConnected(i)) && !IsFakeClient(i))
		{
			clients++;
		}
	}
	
	return clients;
} 