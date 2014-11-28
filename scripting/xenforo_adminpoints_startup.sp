#pragma semicolon 1

//Required Includes
#include <sourcemod>

//API Natives/Forwards
#include <xenforo_api>

#define PLUGIN_NAME     "XenForo API"
#define PLUGIN_AUTHOR   "Keith Warren(Jack of Designs)"
#define PLUGIN_VERSION  "1.0.0"
#define PLUGIN_DESCRIPTION	"API for Xenforo forum installations."
#define PLUGIN_CONTACT  "http://www.jackofdesigns.com/"

new Start = -1;

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
	CreateTimer(60.0, GrantAdminPoints);
}

public XF_OnProcessed(client)
{
	if (Start == -1 && CheckCommandAccess(client, "", ADMFLAG_GENERIC))
	{
		if (GetRealClientCount() < 2)
		{
			Start = client;
		}
	}
}

public OnClientDisconnect(client)
{
	if (client == Start)
	{
		Start = -1;
	}
}

public Action:GrantAdminPoints(Handle:hTimer)
{
	if (Start == -1) return Plugin_Continue;
	
	new client = GetClientOfUserId(Start);
	
	if (GetRealClientCount() >= 12)
	{
		decl String:sQuery[64];
		Format(sQuery, sizeof(sQuery), "UPDATE xf_user_field_value SET field_value = field_value + 2 WHERE user_id = '%i' AND field_id = 'adminpoints'", XenForo_GrabClientID(client));
		XenForo_TQuery(AddPoints, sQuery);
	}
	
	return Plugin_Continue;
}

public AddPoints(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		XenForo_LogToFile(DEFAULT, "Error setting Admin Points: '%s'", error);
		return;
	}
	
	new client = GetClientOfUserId(Start);
	
	if (!client) return;
	PrintToChat(client, "You have received 2 admin points!");
}

GetRealClientCount( bool:inGameOnly = true )
{
	new clients = 0;
	for( new i = 0; i < GetMaxClients(); i++ )
	{
		if( ( ( inGameOnly ) ? IsClientInGame( i ) : IsClientConnected( i ) ) && !IsFakeClient( i ) )
		{
			clients++;
		}
	}
	return clients;
}