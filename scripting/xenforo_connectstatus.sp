#pragma semicolon 1

//Required Includes
#include <sourcemod>
#include <multicolors>
#include <extended_logging>
#include <xenforo/xenforo_api>

//New Syntax
#pragma newdecls required

//Defines
#define PLUGIN_NAME     "XenForo Connect Status"
#define PLUGIN_AUTHOR   "Keith Warren(Drixevel)"
#define PLUGIN_VERSION  "1.0.0"
#define PLUGIN_DESCRIPTION	"Displays status updates on connect for players."
#define PLUGIN_CONTACT  "http://www.drixevel.com/"
#define TAG  "{orange}[DYNF]{default}"

public Plugin myinfo = 
{
	name = PLUGIN_NAME, 
	author = PLUGIN_AUTHOR, 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = PLUGIN_CONTACT
};

public void OnPluginStart()
{
	HookEvent("player_connect", event_PlayerConnect, EventHookMode_Pre);
}

public void XF_OnProcessed(int client)
{
	char auth[64];
	GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
	
	char sQuery[64];
	Format(sQuery, sizeof(sQuery), "SELECT status FROM xf_user_profile WHERE user_id = '%i' ", XenForo_GrabClientID(client));
	XenForo_TQuery(ConnectMessage, sQuery, GetClientUserId(client));
}

public int ConnectMessage(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		XenForo_LogToFile(DEFAULT, "Error grabbing User Info: '%s'", error);
		return;
	}
	
	int client = GetClientOfUserId(data);
	
	if (client > 0 && SQL_FetchRow(hndl))
	{
		char sStatus[128];
		SQL_FetchString(hndl, 0, sStatus, sizeof(sStatus));
		CPrintToChatAll("%s {yellow}%N {default}has connected. Status: {skyblue}%s", TAG, client, strlen(sStatus) != 0 ? sStatus : "No Status Found.");
	}
}

public Action event_PlayerConnect(Handle event, const char[] name, bool dontBroadcast)
{
	if (!dontBroadcast)
	{
		char clientName[33]; char networkID[22]; char address[32];
		GetEventString(event, "name", clientName, sizeof(clientName));
		GetEventString(event, "networkid", networkID, sizeof(networkID));
		GetEventString(event, "address", address, sizeof(address));
		
		Handle newEvent = CreateEvent("player_connect", true);
		SetEventString(newEvent, "name", clientName);
		SetEventInt(newEvent, "index", GetEventInt(event, "index"));
		SetEventInt(newEvent, "userid", GetEventInt(event, "userid"));
		SetEventString(newEvent, "networkid", networkID);
		SetEventString(newEvent, "address", address);
		
		FireEvent(newEvent, true);
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
} 