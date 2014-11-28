#pragma semicolon 1

//Required Includes
#include <sourcemod>

//API Natives/Forwards
#include <xenforo_api>

#define PLUGIN_NAME     "XenForo Servers List"
#define PLUGIN_AUTHOR   "Keith Warren(Jack of Designs)"
#define PLUGIN_VERSION  "1.0.0"
#define PLUGIN_DESCRIPTION	"List all servers and allow connections to them."
#define PLUGIN_CONTACT  "http://www.jackofdesigns.com/"

new Handle:hMenu = INVALID_HANDLE;

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
	RegConsoleCmd("sm_servers", ServersList);
}

public OnConfigsExecuted()
{
	if (hMenu != INVALID_HANDLE)
	{
		CloseHandle(hMenu);
		hMenu = INVALID_HANDLE;
	}
	
	hMenu = CreateMenu(MenuHandler);
	SetMenuTitle(hMenu, "Pick a Server:");
	SetMenuExitButton(hMenu, true);
	
	if (XenForo_IsConnected())
	{
		decl String:sQuery[1024];
		FormatEx(sQuery, sizeof(sQuery), "SELECT option_value FROM `xf_option` WHERE option_id = 'stentor_server_ips' ");
		XenForo_TQuery(QueryServers, sQuery);
	}
}

public Action:ServersList(client, args)
{
	if (!IsClientInGame(client))
	{
		ReplyToCommand(client, "%t", "Command is in-game only");
		return Plugin_Handled;
	}
	
	if (!DisplayMenu(hMenu, client, MENU_TIME_FOREVER))
	{
		PrintToChat(client, "Menu cannot be displayed, please contact an administrator.");
	}
	
	return Plugin_Handled;
}

public QueryServers(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		XenForo_LogToFile(TRACE, "Error parsing servers: '%s'", error);
		return;
	}
	
	new rows = SQL_GetRowCount(hndl);

	if (rows > 0)
	{
		if (GetMenuItemCount(hMenu) > 0)
		{
			RemoveAllMenuItems(hMenu);
		}
		
		for (new i = 0; i < rows; i++)
		{
			SQL_FetchRow(hndl);
			
			decl String:sIPAddresses[256];
			SQL_FetchString(hndl, i, sIPAddresses, sizeof(sIPAddresses));
			
			AddMenuItem(hMenu, sIPAddresses, sIPAddresses);
		}
	}
}

public MenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
			{
				
			}
	}
}