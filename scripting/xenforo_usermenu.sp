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
#define TAG  "[User]"

enum PlayerData
{
	String:sUsername[MAX_NAME_LENGTH],
	Float:fCredits,
	iAdminPoints
}

new g_PlayerData[MAXPLAYERS+1][PlayerData];

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
	RegConsoleCmd("sm_xfmenu", XenForoMenu);
}

public XF_OnProcessed(client)
{
	g_PlayerData[client][iAdminPoints] = 0;
	
	decl String:sQuery[64];
	Format(sQuery, sizeof(sQuery), "SELECT field_value FROM xf_user_field_value WHERE user_id = '%i' AND field_id = 'adminpoints'", XenForo_GrabClientID(client));
	XenForo_TQuery(GrabAdminPoints, sQuery, GetClientUserId(client));
}

public GrabAdminPoints(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		XenForo_LogToFile(DEFAULT, "Error grabbing Admin Points: '%s'", error);
		return;
	}
	
	new client = GetClientOfUserId(data);
	
	if (!client) return;
	
	if (SQL_FetchRow(hndl))
	{	
		g_PlayerData[client][iAdminPoints] = SQL_FetchInt(hndl, 0);
	}
}

public Action:XenForoMenu(client, args)
{
	new xfid = XenForo_GrabClientID(client);
	
	if (xfid == -1)
	{
		ReplyToCommand(client, "You're currently not processed.");
		return Plugin_Handled;
	}
	
	decl String:sQuery[64];
	Format(sQuery, sizeof(sQuery), "SELECT * FROM xf_user WHERE user_id = '%i' ", xfid);
	XenForo_TQuery(DisplayUserInfo, sQuery, GetClientUserId(client));
	
	return Plugin_Handled;
}

public DisplayUserInfo(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		XenForo_LogToFile(DEFAULT, "Error grabbing User Info: '%s'", error);
		return;
	}
	
	new client = GetClientOfUserId(data);
	
	if (!client) return;
	
	new Handle:hMenu = CreateMenu(MenuHandler);
	SetMenuTitle(hMenu, "Website Account Info");
	SetMenuExitButton(hMenu, true);
	
	if (SQL_FetchRow(hndl))
	{
		new field_id;
		
		new String:sName[128];
		SQL_FieldNameToNum(hndl, "username", field_id);
		SQL_FetchString(hndl, field_id, sName, sizeof(sName));
		AddMenuItem(hMenu, "", sName);
		
		new String:sCredits[128], Float:fCreditsT;
		SQL_FieldNameToNum(hndl, "credits", field_id);
		fCreditsT = SQL_FetchFloat(hndl, field_id);
		Format(sCredits, sizeof(sCredits), "Credits: %f", fCreditsT);
		AddMenuItem(hMenu, "", sCredits);
		
		new String:sAdminPoints[128];
		Format(sAdminPoints, sizeof(sAdminPoints), "Admin Points: %i", g_PlayerData[client][iAdminPoints]);
		AddMenuItem(hMenu, "", sAdminPoints);
	}
	
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler(Handle:hMenu, MenuAction:action, param1, param2)
{
	switch (action)
	{
	case MenuAction_Select:
		{
		
		}
	case MenuAction_End:
		{
			CloseHandle(hMenu);
		}
	}
}