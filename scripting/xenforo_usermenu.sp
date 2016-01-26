#pragma semicolon 1

//Required Includes
#include <sourcemod>
#include <multicolors>
#include <extended_logging>
#include <xenforo/xenforo_api>

//New Syntax
#pragma newdecls required

//Defines
#define PLUGIN_NAME     "XenForo User Menu"
#define PLUGIN_AUTHOR   "Keith Warren(Drixevel)"
#define PLUGIN_VERSION  "1.0.0"
#define PLUGIN_DESCRIPTION	"Grants access to XenForo user menu to display information."
#define PLUGIN_CONTACT  "http://www.drixevel.com/"
#define TAG  "[User]"

enum PlayerData
{
	String:sUsername[MAX_NAME_LENGTH], 
	Float:fCredits, 
	iAdminPoints
}

int g_PlayerData[MAXPLAYERS + 1][PlayerData];

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
	RegConsoleCmd("sm_xfmenu", XenForoMenu);
}

public void XF_OnProcessed(int client)
{
	g_PlayerData[client][iAdminPoints] = 0;
	
	char sQuery[2048];
	Format(sQuery, sizeof(sQuery), "SELECT field_value FROM xf_user_field_value WHERE user_id = '%i' AND field_id = 'adminpoints'", XenForo_GrabClientID(client));
	XenForo_TQuery(GrabAdminPoints, sQuery, GetClientUserId(client));
}

public int GrabAdminPoints(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		XenForo_LogToFile(DEFAULT, "Error grabbing Admin Points: '%s'", error);
		return;
	}
	
	int client = GetClientOfUserId(data);
	
	if (client > 0 && SQL_FetchRow(hndl))
	{
		g_PlayerData[client][iAdminPoints] = SQL_FetchInt(hndl, 0);
	}
}

public Action XenForoMenu(int client, int args)
{
	int xfid = XenForo_GrabClientID(client);
	
	if (xfid == -1)
	{
		ReplyToCommand(client, "You're currently not processed.");
		return Plugin_Handled;
	}
	
	char sQuery[64];
	Format(sQuery, sizeof(sQuery), "SELECT * FROM xf_user WHERE user_id = '%i' ", xfid);
	XenForo_TQuery(DisplayUserInfo, sQuery, GetClientUserId(client));
	
	return Plugin_Handled;
}

public void DisplayUserInfo(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == INVALID_HANDLE)
	{
		XenForo_LogToFile(DEFAULT, "Error grabbing User Info: '%s'", error);
		return;
	}
	
	int client = GetClientOfUserId(data);
	
	if (client < 0)
	{
		return;
	}
	
	Handle hMenu = CreateMenu(MenuHandler);
	SetMenuTitle(hMenu, "Website Account Info");
	SetMenuExitButton(hMenu, true);
	
	if (SQL_FetchRow(hndl))
	{
		int field_id;
		
		char sName[128];
		SQL_FieldNameToNum(hndl, "username", field_id);
		SQL_FetchString(hndl, field_id, sName, sizeof(sName));
		AddMenuItem(hMenu, "", sName);
		
		char sCredits[128]; float fCreditsT;
		SQL_FieldNameToNum(hndl, "credits", field_id);
		fCreditsT = SQL_FetchFloat(hndl, field_id);
		Format(sCredits, sizeof(sCredits), "Credits: %f", fCreditsT);
		AddMenuItem(hMenu, "", sCredits);
		
		char sAdminPoints[128];
		Format(sAdminPoints, sizeof(sAdminPoints), "Admin Points: %i", g_PlayerData[client][iAdminPoints]);
		AddMenuItem(hMenu, "", sAdminPoints);
	}
	
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public int MenuHandler(Handle hMenu, MenuAction action, int param1, int param2)
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