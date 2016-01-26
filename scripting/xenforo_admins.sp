#pragma semicolon 1

#include <sourcemod>
#include <multicolors>
#include <extended_logging>
#include <SteamWorks>
#include <xenforo/xenforo_api>

//New Syntax
#pragma newdecls required

//Defines

//Globals
Handle g_hFastLookupTrie;

bool IsConfigLoaded;
bool bIsAPIRunning;
bool bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	bLateLoad = late;
	return APLRes_Success;
}

public Plugin myinfo = 
{
	name = "XenForo Admins System", 
	author = "Keith Warren(Drixevel), original code by Kyle Sanderson", 
	description = "Grants players flags based on groups for XenForo.", 
	version = "1.0.0", 
	url = "http://www.drixevel.com/"
};

public void OnPluginStart()
{
	g_hFastLookupTrie = CreateTrie();
}

public void OnConfigsExecuted()
{
	ReparseConfig();
	
	if (bLateLoad && XenForo_IsConnected())
	{
		XF_OnConnected();
	}
}

public void OnAllPluginsLoaded()
{
	bIsAPIRunning = LibraryExists("xenforo_api");
}

public void OnLibraryAdded(const char[] sName)
{
	bIsAPIRunning = StrEqual(sName, "xenforo_api", false);
}

public void OnLibraryRemoved(const char[] sName)
{
	bIsAPIRunning = StrEqual(sName, "xenforo_api", false);
}

public void XF_OnConnected()
{
	if (bIsAPIRunning)
	{
		QueryAdmins();
	}
}

public void OnRebuildAdminCache(AdminCachePart part)
{
	if (!bIsAPIRunning)
	{
		return;
	}
	
	switch (part)
	{
		case AdminCache_Admins:QueryAdmins();
		case AdminCache_Groups:ReparseConfig();
	}
}

void QueryAdmins()
{
	char sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "SELECT ufv.provider_key, u.username, u.user_group_id, u.secondary_group_ids FROM xf_user_external_auth AS ufv LEFT JOIN xf_user AS u ON (u.user_id = ufv.user_id) WHERE ufv.provider = 'steam' ");
	XenForo_TQuery(SendQuery, sQuery, 0, DBPrio_High);
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
	
	char sCommunityID[64]; char sSteamID[64]; char sName[256]; char sUserID[256]; char sSecondaryIDs[256];
	AdminId iAdminID; DBResult iResult;
	
	while (SQL_FetchRow(hndl))
	{
		SQL_FetchString(hndl, 0, sCommunityID, sizeof(sCommunityID), iResult);
		XenForo_LogToFile(TRACE, "Retrieving data for CommunityID '%s'...", sCommunityID);
		
		SteamIDToCommunityID(sCommunityID, sSteamID, sizeof(sSteamID));
		XenForo_LogToFile(TRACE, "Converting '%s' to '%s' via 'Steam_CSteamIDToRenderedID' stock.", sCommunityID, sSteamID);
		
		if (iResult != DBVal_Data)
		{
			XenForo_LogToFile(TRACE, "No search results found");
			continue;
		}
		
		TrimString(sSteamID);
		
		iAdminID = FindAdminByIdentity(sSteamID, AUTHMETHOD_STEAM);
		
		if (iAdminID == INVALID_ADMIN_ID)
		{
			SQL_FetchString(hndl, 1, sName, sizeof(sName), iResult);
			XenForo_LogToFile(TRACE, "SQL 1 = sName: %s", sName);
			
			if (iResult != DBVal_Data)
			{
				XenForo_LogToFile(TRACE, "No search results found. 135");
				continue;
			}
			
			TrimString(sName);
			
			iAdminID = CreateAdmin(sName);
			BindAdminIdentity(iAdminID, AUTHMETHOD_STEAM, sSteamID);
			XenForo_LogToFile(TRACE, "Admin identity created/binded. [%i, %s]", iAdminID, sSteamID);
		}
		
		sName[0] = '\0';
		SQL_FetchString(hndl, 2, sUserID, sizeof(sUserID), iResult);
		XenForo_LogToFile(TRACE, "SQL 2 = sUserID: %s", sUserID);
		
		if (iResult != DBVal_Data)
		{
			XenForo_LogToFile(TRACE, "No search results found. 150");
			continue;
		}
		
		TrimString(sUserID);
		
		SQL_FetchString(hndl, 3, sSecondaryIDs, sizeof(sSecondaryIDs), iResult);
		XenForo_LogToFile(TRACE, "SQL 3 = sSecondaryIDs: %s", sSecondaryIDs);
		
		if (iResult == DBVal_Data)
		{
			XenForo_LogToFile(TRACE, "iResult == DBVal_Data");
			TrimString(sSecondaryIDs);
			
			if (sSecondaryIDs[0] != '\0')
			{
				XenForo_LogToFile(TRACE, "sSecondaryIDs != 0 [%s]", sSecondaryIDs);
				if (sUserID[0] != '\0')
				{
					Format(sUserID, sizeof(sUserID), "%s,%s", sUserID, sSecondaryIDs);
					XenForo_LogToFile(TRACE, "sUserID != 0, [%s, %s]", sUserID, sSecondaryIDs);
				}
				else
				{
					strcopy(sUserID, sizeof(sUserID), sSecondaryIDs);
					XenForo_LogToFile(TRACE, "sUserID == 0, [%s, %s]", sUserID);
				}
			}
		}
		
		if (sUserID[0] == '\0')
		{
			XenForo_LogToFile(TRACE, "sUserID [%s] == 0", sUserID);
			continue;
		}
		
		TrimString(sUserID);
		AddAdminToGroups(iAdminID, sUserID);
		
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
			XenForo_LogToFile(TRACE, "AdminInheritGroup: [%i, %i, %s]", iAdminID, iAdminGroup, sConstruction);
		}
		
		iCurPos = 0;
	}
}

void LateLoadAdminCall()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
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
	
	GroupId g_iXFGroupIndex = INVALID_GROUP_ID;
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