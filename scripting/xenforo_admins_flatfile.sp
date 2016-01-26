#pragma semicolon 1

#include <sourcemod>
#include <multicolors>
#include <extended_logging>
#include <SteamWorks>
//#include <ccc>
#include <xenforo/xenforo_api>

//New Syntax
#pragma newdecls required

//Defines
#define PLUGIN_NAME     "XenForo Admins System - Configs"
#define PLUGIN_AUTHOR   "Keith Warren(Drixevel), original code by Kyle Sanderson"
#define PLUGIN_VERSION  "1.0.0"
#define PLUGIN_DESCRIPTION	"Grants players flags based on groups for XenForo and saves them to file."
#define PLUGIN_CONTACT  "http://www.drixevel.com/"

Handle g_hFastLookupTrie;

bool IsConfigLoaded;
bool bIsAPIRunning;
bool bLateLoad;

GroupId g_iXFGroupIndex = INVALID_GROUP_ID;

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
	bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hFastLookupTrie = CreateTrie();
}

public void OnConfigsExecuted()
{
	ReparseConfig();
	
	if (bLateLoad)
	{
		if (XenForo_IsConnected())
		{
			XF_OnConnected();
		}
		
		bLateLoad = false;
	}
}

public void XF_OnConnected()
{
	bIsAPIRunning = true;
	QueryAdmins();
}

public void OnRebuildAdminCache(AdminCachePart part)
{
	switch (part)
	{
		case AdminCache_Admins:QueryAdmins();
		case AdminCache_Groups:ReparseConfig();
	}
}

public void OnClientPostAdminCheck(int client)
{
	if (IsClientInGame(client) && !CheckCommandAccess(client, "", ADMFLAG_RESERVATION))
	{
		char sID[64];
		GetClientAuthId(client, AuthId_Steam2, sID, sizeof(sID));
		
		char Config[PLATFORM_MAX_PATH];
		Handle hConfig = CreateKeyValues("CustomJoinMessages");
		
		BuildPath(Path_SM, Config, 64, "data/cannounce_messages.txt");
		FileToKeyValues(hConfig, Config);
		
		KvGotoFirstSubKey(hConfig);
		KvDeleteKey(hConfig, sID);
		
		CloseHandle(hConfig);
	}
}

void QueryAdmins()
{
	if (bIsAPIRunning)
	{
		char sQuery[1024];
		FormatEx(sQuery, sizeof(sQuery), "SELECT ufv.provider_key, u.username, u.user_group_id, u.secondary_group_ids FROM xf_user_external_auth AS ufv LEFT JOIN xf_user AS u ON (u.user_id = ufv.user_id) WHERE ufv.provider = 'steam' ");
		XenForo_TQuery(SendQuery, sQuery, 0, DBPrio_High);
	}
}

public int SendQuery(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		XenForo_LogToFile(TRACE, "Error parsing admins: '%s'", error);
		LateLoadAdminCall();
		return;
	}
	
	if (!IsConfigLoaded)
	{
		LateLoadAdminCall();
		return;
	}
	
	char sCommunityID[256]; char sSteamID[256]; char sName[256];
	AdminId iAdminID; DBResult iResult;
	
	while (SQL_FetchRow(hndl))
	{
		SQL_FetchString(hndl, 0, sCommunityID, sizeof(sCommunityID), iResult);
		
		SteamIDToCommunityID(sCommunityID, sSteamID, sizeof(sSteamID));
		XenForo_LogToFile(TRACE, "Converting %s to %s via SteamTools.", sCommunityID, sSteamID);
		
		if (iResult != DBVal_Data)
		{
			continue;
		}
		
		TrimString(sSteamID);
		
		iAdminID = FindAdminByIdentity(sSteamID, AUTHMETHOD_STEAM);
		
		if (iAdminID == INVALID_ADMIN_ID)
		{
			SQL_FetchString(hndl, 1, sName, sizeof(sName), iResult);
			
			if (iResult != DBVal_Data)
			{
				continue;
			}
			
			TrimString(sName);
			
			iAdminID = CreateAdmin(sName);
			BindAdminIdentity(iAdminID, AUTHMETHOD_STEAM, sSteamID);
		}
		
		sName[0] = '\0';
		SQL_FetchString(hndl, 2, sName, sizeof(sName), iResult);
		
		if (iResult != DBVal_Data)
		{
			continue;
		}
		
		TrimString(sName);
		
		SQL_FetchString(hndl, 3, sSteamID, sizeof(sSteamID), iResult);
		
		if (iResult == DBVal_Data)
		{
			TrimString(sSteamID);
			
			if (sSteamID[0] != '\0')
			{
				if (sName[0] != '\0')
				{
					Format(sName, sizeof(sName), "%s,%s", sName, sSteamID);
				}
				else
				{
					strcopy(sName, sizeof(sName), sSteamID);
				}
			}
		}
		
		if (sName[0] == '\0')
		{
			continue;
		}
		
		TrimString(sName);
		AddAdminToGroups(iAdminID, sName);
		
		XenForo_LogToFile(TRACE, "Parsing cache to add [%s, %s, %s].", sCommunityID, sSteamID, sName);
	}
	
	LateLoadAdminCall();
}

void AddAdminToGroups(AdminId iAdminID, const char[] sGroups)
{
	int iStrSize = (strlen(sGroups) + 1);
	char[] sConstruction = new char[iStrSize];
	
	GroupId iAdminGroup;
	int iCurPos;
	
	int iChar;
	
	for (int i; i < iStrSize; i++)
	{
		iChar = sGroups[i];
		if (iChar != ',' && iChar != '\0')
		{
			sConstruction[iCurPos] = iChar;
			iCurPos++;
			continue;
		}
		
		if (iCurPos == 0)
		{
			continue;
		}
		
		sConstruction[iCurPos] = '\0';
		
		TrimString(sConstruction);
		if (GetTrieValue(g_hFastLookupTrie, sConstruction, iAdminGroup))
		{
			AdminInheritGroup(iAdminID, iAdminGroup);
		}
		
		iCurPos = 0;
	}
}

void LateLoadAdminCall()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			RunAdminCacheChecks(i);
			NotifyPostAdminCheck(i);
		}
	}
}

bool ReparseConfig()
{
	if (!bIsAPIRunning)
	{
		return false;
	}
	
	DumpAdminCache(AdminCache_Groups, false);
	
	XenForo_LogToFile(TRACE, "Parse starting for admins config...");
	
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/xenforo_admins.cfg");
	
	if (!FileExists(sPath))
	{
		IsConfigLoaded = false;
		XenForo_LogToFile(TRACE, "File not found: [%s]", sPath);
		return false;
	}
	
	Handle hConfig = CreateKeyValues("xenforo_admins");
	FileToKeyValues(hConfig, sPath);
	
	if (!KvGotoFirstSubKey(hConfig, false))
	{
		IsConfigLoaded = false;
		XenForo_LogToFile(TRACE, "While parsing configuration file for admins, couldn't go to first sub key.");
		return false;
	}
	
	ClearTrie(g_hFastLookupTrie);
	
	g_iXFGroupIndex = INVALID_GROUP_ID;
	char sBuffer[255]; char sFlags[255];
	
	do
	{
		KvGetSectionName(hConfig, sBuffer, sizeof(sBuffer));
		XenForo_LogToFile(TRACE, "Iterating section name %s.", sBuffer);
		
		if (!GetTrieValue(g_hFastLookupTrie, sBuffer, g_iXFGroupIndex))
		{
			g_iXFGroupIndex = CreateAdmGroup(sBuffer);
			XenForo_LogToFile(TRACE, "Creating admin group for index %i [%s].", g_iXFGroupIndex, sBuffer);
			
			if (g_iXFGroupIndex == INVALID_GROUP_ID)
			{
				g_iXFGroupIndex = FindAdmGroup(sBuffer);
				XenForo_LogToFile(TRACE, "Admin group failed to be created, checking if it exists and if it does, hook it. Index: [%i], Name: [%s]", g_iXFGroupIndex, sBuffer);
				
				if (g_iXFGroupIndex == INVALID_GROUP_ID)
				{
					XenForo_LogToFile(TRACE, "Failed to create or find group, aborting this section. Index: [%i], Name: [%s]", g_iXFGroupIndex, sBuffer);
					continue;
				}
			}
		}
		
		SetTrieValue(g_hFastLookupTrie, sBuffer, g_iXFGroupIndex, true);
		
		KvGetString(hConfig, "Flags", sFlags, sizeof(sFlags));
		XenForo_LogToFile(TRACE, "Adding flags for %s: %s", sBuffer, sFlags);
		
		AdminFlag iFoundFlag;
		for (int i = strlen(sFlags); i >= 0; i--)
		{
			if (FindFlagByChar(sFlags[i], iFoundFlag))
			{
				SetAdmGroupAddFlag(g_iXFGroupIndex, iFoundFlag, true);
			}
		}
		
		int Immunity = KvGetNum(hConfig, "Immunity", 1);
		SetAdmGroupImmunityLevel(g_iXFGroupIndex, Immunity);
		XenForo_LogToFile(TRACE, "Immunity level set for %s: %i", sBuffer, Immunity);
		
	} while (KvGotoNextKey(hConfig, false));
	
	g_iXFGroupIndex = INVALID_GROUP_ID;
	
	IsConfigLoaded = true;
	XenForo_LogToFile(TRACE, "Parsing complete for admins config!");
	return true;
} 