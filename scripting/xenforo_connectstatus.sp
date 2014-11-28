#pragma semicolon 1

//Required Includes
#include <sourcemod>
#include <MoreColors>

//API Natives/Forwards
#include <xenforo_api>

#define PLUGIN_NAME     "XenForo Connect Status"
#define PLUGIN_AUTHOR   "Keith Warren(Jack of Designs)"
#define PLUGIN_VERSION  "1.0.0"
#define PLUGIN_DESCRIPTION	"Displays status updates on connect for players."
#define PLUGIN_CONTACT  "http://www.jackofdesigns.com/"
#define TAG  "{orange}[DYNF]{default}"

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_CONTACT
};

public OnPluginStart()
{
	HookEvent("player_connect", event_PlayerConnect, EventHookMode_Pre);
}

public XF_OnProcessed(client)
{
	decl String:auth[64];
	GetClientAuthString(client, auth, sizeof(auth));
	
	decl String:sQuery[64];
	Format(sQuery, sizeof(sQuery), "SELECT status FROM xf_user_profile WHERE user_id = '%i' ", XenForo_GrabClientID(client));
	XenForo_TQuery(ConnectMessage, sQuery, GetClientUserId(client));
}

public ConnectMessage(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		XenForo_LogToFile(DEFAULT, "Error grabbing User Info: '%s'", error);
		return;
	}
	
	new client = GetClientOfUserId(data);
	
	if (!client) return;
	
	if (SQL_FetchRow(hndl))
	{
		new String:sStatus[128];
		SQL_FetchString(hndl, 0, sStatus, sizeof(sStatus));
		if (strlen(sStatus) == 0) Format(sStatus, sizeof(sStatus), "No status found.");
		CPrintToChatAll("%s {yellow}%N {default}has connected. Status: {skyblue}%s", TAG, client, sStatus);
	}
}

public Action:event_PlayerConnect(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (!dontBroadcast)
    {
        decl String:clientName[33], String:networkID[22], String:address[32];
        GetEventString(event, "name", clientName, sizeof(clientName));
        GetEventString(event, "networkid", networkID, sizeof(networkID));
        GetEventString(event, "address", address, sizeof(address));

        new Handle:newEvent = CreateEvent("player_connect", true);
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