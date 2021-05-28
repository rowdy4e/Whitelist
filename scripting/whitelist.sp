#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Rowdy4E."
#define PLUGIN_VERSION "1.00"

#define PLUGIN_CONFIG "configs/whitelist.cfg"

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Whitelist",
	author = PLUGIN_AUTHOR,
	description = "Whitelist based on client's steamid2.",
	version = PLUGIN_VERSION,
	url = "https://github.com/rowdy4e"
};

char AuthIdPrefixes[][] =  { "STEAM_1:0:", "STEAM_1:1:", "STEAM_0:1:", "STEAM_0:0:" };

ArrayList aWhitelist;

ConVar cvCommands;
ConVar cvAdminFlag;
char cAdminFlag[2];

ConVar cvKickMessage;
char cKickMessage[255];

public void OnPluginStart()
{
	cvCommands = CreateConVar("wl_commands", "wl, whitelist, whitel", "Set custom commands.");
	cvAdminFlag = CreateConVar("wl_admin_flag", "z", "Ignores admin flag from whitelist\nLeave empty if you don't want to allow any admin flag to connect without restriction.");
	cvKickMessage = CreateConVar("wl_kick_message", "You are not on whitelist!");
	
	AutoExecConfig(true, "whitelist");
	
	aWhitelist = new ArrayList(24);
	aWhitelist.Clear();
	
	LoadWhitelistConfig();
}

public void OnPluginEnd() {
	SaveWhitelistConfig();
}

public void OnConfigsExecuted() {
	char commands[255];
	cvCommands.GetString(commands, sizeof(commands));
	RegisterCommands(commands, Command_Whitelist);
	cvKickMessage.GetString(cKickMessage, sizeof(cKickMessage));
	cvAdminFlag.GetString(cAdminFlag, sizeof(cAdminFlag));
}

void SaveWhitelistConfig(int client = 0) {
	char Path[248];
	BuildPath(Path_SM, Path, sizeof(Path), "%s", PLUGIN_CONFIG);
	
	Handle hFile;
	hFile = OpenFile(Path, "w");
	if (hFile != null) {
		char authId[24];
		for (int i = 0; i < aWhitelist.Length; i++) {
			if (aWhitelist.GetString(i, authId, sizeof(authId)) != -1)
				WriteFileLine(hFile, "STEAM_1:0:%s", authId);
		}
		
		delete hFile;
	}
	
	if (client == 0)
		PrintToServer("Whitelist config successfuly saved.");
	else
		PrintToChat(client, " \x06Whitelist config successfuly saved.");
}

void ReloadWhitelistConfig(int client) {
	aWhitelist.Clear();
	
	LoadWhitelistConfig();
	
	if (client == 0)
		PrintToServer("Whitelist config successfully reloaded.");
	else
		PrintToChat(client, " \x06Whitelist config successfully reloaded.");
}

void LoadWhitelistConfig() {
	char Path[248];
	BuildPath(Path_SM, Path, sizeof(Path), "%s", PLUGIN_CONFIG);
	
	Handle hFile;
	if (!FileExists(Path)) {
		hFile = OpenFile(Path, "w");
		if (hFile != null) {
			WriteFileLine(hFile, "# List of steam ids allowed to join the server.\nSTEAM_0:1:123\nSTEAM_0:1:321");
			delete hFile;
		}
	}
	
	char buffer[512];
	hFile = OpenFile(Path, "r");
	
	if (hFile != null) {
		while (ReadFileLine(hFile, buffer, sizeof(buffer))) {		
			if (strlen(buffer) > 0 && buffer[strlen(buffer) - 1] == '\n')
				buffer[strlen(buffer) - 1] = '\0';
			TrimString(buffer);
			if (strlen(buffer) == 0)
				continue;
			if (StrContains(buffer, "\\") != -1)
				ReplaceString(buffer, sizeof(buffer), "\\", "/");
			if (StrContains(buffer, "//") != -1 || StrContains(buffer, "#") != -1)
				continue; 
			if (StrContains(buffer, "STEAM_", false) == -1)
				continue;
			
			char authId[24];
			strcopy(authId, sizeof(authId), buffer[10]);
			if (aWhitelist.FindString(authId) == -1)
				aWhitelist.PushString(authId);
		}
		delete hFile;
	}
}

public void OnClientPostAdminCheck(int client) {
	if (!IsOnWhitelist(client))
		KickClient(client, cKickMessage);
}

public Action Command_Whitelist(int client, int args) {
	char cmd[24];
	GetCmdArg(0, cmd, sizeof(cmd));
	if (args < 1) {
		if (client == 0)
			PrintToServer("Usage: %s <add|del|reload|clear|save>", cmd);
		else 
			PrintToChat(client, "Usage: %s <add|del|reload|clear|save>", cmd);
		return Plugin_Continue;
	}
	
	char arg[255];
	GetCmdArgString(arg, sizeof(arg));
	
	char cInfo[2][64];
	ExplodeString(arg, " ", cInfo, 2, 64);
	
	char action[24], param[24], authId[24];
	strcopy(action, sizeof(action), cInfo[0]);
	strcopy(param, sizeof(param), cInfo[1]);
	
	if (StrEqual(action, "add", false)) {
		if (!HasCorrectSteamPrefix(param)) {
			if (client == 0)
				PrintToServer("Usage: %s %s STEAM_X:X:XXXX", cmd, action);
			else
				PrintToChat(client, "Usage: %s %s STEAM_X:X:XXXX", cmd, action);
			return Plugin_Continue;
		}
		
		strcopy(authId, sizeof(authId), param[10]);
		
		if (aWhitelist.FindString(authId) != -1) {
			if (client == 0)
				PrintToServer("%s is already on whitelist!", param);
			else
				PrintToChat(client, " \x02%s is already on whitelist!", param);
		} else {
			aWhitelist.PushString(authId);
			if (client == 0)
				PrintToServer("%s successfuly added to whitelist.", param);
			else
				PrintToChat(client, " \x06%s successfuly added to whitelist.", param);
		}
		
	} else if (StrEqual(action, "del", false) || StrEqual(action, "rem", false)) {
		if (!HasCorrectSteamPrefix(param)) {
			if (client == 0)
				PrintToServer("Usage: %s %s STEAM_X:X:XXXX", cmd, action);
			else
				PrintToChat(client, "Usage: %s %s STEAM_X:X:XXXX", cmd, action);
			return Plugin_Continue;
		}
		
		strcopy(authId, sizeof(authId), param[10]);
		
		int id;
		if ((id = aWhitelist.FindString(authId)) != -1) {
			aWhitelist.Erase(id);
			if (client == 0)
				PrintToServer("%s successfuly removed from whitelist.", param);
			else
				PrintToChat(client, " \x06%s successfuly removed from whitelist.", param);
		} else {
			if (client == 0)
				PrintToServer("%s was not found in whitelist!", param);
			else
				PrintToChat(client, " \x02%s was not found in whitelist!", param);
		}
	} else if (StrEqual(action, "reload", false)) {
		ReloadWhitelistConfig(client);
	} else if (StrEqual(action, "clear", false)) {
		aWhitelist.Clear();
		if (client == 0)
			PrintToServer("Whitelist is now empty.");
		else 
			PrintToChat(client, " \x06Whitelist is now empty.");
	} else if (StrEqual(action, "save", false)) {
		SaveWhitelistConfig(client);
	}
	
	
	return Plugin_Handled;
}

bool HasAdminFlag(int client, char[] flag) {
	if (strlen(flag) <= 0)
		return false;
	
	AdminId admin = GetUserAdmin(client);
	AdminFlag adminFlag;
	
	if (!FindFlagByChar(flag[0], adminFlag)) {
		return false;
	} else if (!GetAdminFlag(admin, adminFlag)) {
		return false;
	}
	return true;
}

bool HasCorrectSteamPrefix(char[] authid) {
	for (int i = 0; i < sizeof(AuthIdPrefixes); i++) {
		if (StrContains(authid, AuthIdPrefixes[i], false) != -1)
			return true;
	}
	
	return false;
}

bool IsOnWhitelist(int client) {
	char authId[24];
	GetClientAuthId(client, AuthId_Steam2, authId, sizeof(authId));
	strcopy(authId, sizeof(authId), authId[10]);
	
	if (HasAdminFlag(client, cAdminFlag) || aWhitelist.FindString(authId) != -1)
		return true;
		
	return false;
}

void RegisterCommands(char[] commands, ConCmd callback) {
	if (StrContains(commands, " ") != -1)
		ReplaceString(commands, 255, " ", "");
	char cCmds[12][24], cCmd[24];
	int iCmds = ExplodeString(commands, ",", cCmds, 12, 24);
	for (int i = 0; i < iCmds; i++)
	{
		Format(cCmd, sizeof(cCmd), "sm_%s", cCmds[i]);
		if (GetCommandFlags(cCmd) == INVALID_FCVAR_FLAGS) {
			RegConsoleCmd(cCmd, callback);
		}
	}
}