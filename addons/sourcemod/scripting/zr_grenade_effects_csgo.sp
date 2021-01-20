/*  [ZR] CS:GO Grenade Effects
 *
 *  Copyright (C) 2017 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <zombiereloaded>
#include <zr_tools>
#pragma newdecls required

#define PLUGIN_VERSION "2.3.4-B"

#define FLASH 0
#define SMOKE 1

#define ICE_CUBE_MODEL "models/weapons/eminem/ice_cube/ice_cube.mdl"

#define SOUND_FREEZE	"physics/glass/glass_impact_bullet4.wav"
#define SOUND_UNFREEZE	"physics/glass/glass_sheet_break3.wav"
#define SOUND_FREEZE_EXPLODE	"ui/freeze_cam.wav"

#define FragColor 	{255,75,75,255}
#define FlashColor 	{255,255,255,255}
#define SmokeColor	{75,255,75,255}
#define FreezeColor	{75,75,255,255}

float NULL_VELOCITY[3] = {0.0, 0.0, 0.0};

int BeamSprite        = -1;
int GlowSprite        = -1;
int g_beamsprite        = -1;
int g_halosprite        = -1;

int IceRef[MAXPLAYERS + 1];
int SnowRef[MAXPLAYERS + 1];

ConVar g_Cvar_greneffects_enable = null;
ConVar g_Cvar_greneffects_trails = null;
ConVar g_Cvar_greneffects_napalm_he = null;
ConVar g_Cvar_greneffects_napalm_he_duration = null;
ConVar g_Cvar_greneffects_smoke_freeze = null;
ConVar g_Cvar_greneffects_smoke_freeze_distance = null;
ConVar g_Cvar_greneffects_smoke_freeze_duration = null;
ConVar g_Cvar_greneffects_smoke_freeze_icecube = null;
ConVar g_Cvar_greneffects_smoke_freeze_snow = null;
ConVar g_Cvar_greneffects_flash_light = null;
ConVar g_Cvar_greneffects_flash_light_distance = null;
ConVar g_Cvar_greneffects_flash_light_duration = null;
ConVar g_Cvar_greneffects_sound_freeze_enable = null;
ConVar g_Cvar_greneffects_sound_unfreeze_enable = null;
ConVar g_Cvar_greneffects_fire_Movement_Speed = null;

bool b_enable = false;
bool b_trails = false;
bool b_napalm_he = false;
bool b_smoke_freeze = false;
bool b_flash_light = false;
bool b_icecube_enable = false;
bool b_snow_enable = false;
bool b_snow_sound_freeze = false;
bool b_snow_sound_unfreeze = false;
bool b_icecube_active[MAXPLAYERS + 1] = {false, ...};
bool b_snow_active[MAXPLAYERS + 1] = {false, ...};

float f_napalm_he_duration;
float f_smoke_freeze_distance;
float f_smoke_freeze_duration;
float f_flash_light_distance;
float f_flash_light_duration;
float f_fire_Movement_Speed;

Handle h_freeze_timer[MAXPLAYERS+1];

Handle h_fwdOnClientFreeze;
Handle h_fwdOnClientFreezed;
Handle h_fwdOnClientIgnite;
Handle h_fwdOnClientIgnited;
Handle h_fwdOnGrenadeEffect;
Handle h_timers_slow[MAXPLAYERS + 1] = INVALID_HANDLE;

public Plugin myinfo = 
{
	name = "[ZR] CS:GO Grenade Effects",
	author = "FrozDark, Franc1sco franug, Anubis Edition",
	description = "Adds Grenades Special Effects ,Ice Cube.",
	version = PLUGIN_VERSION,
	url = ""
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	h_fwdOnClientFreeze = CreateGlobalForward("ZR_OnClientFreeze", ET_Hook, Param_Cell, Param_Cell, Param_FloatByRef);
	h_fwdOnClientFreezed = CreateGlobalForward("ZR_OnClientFreezed", ET_Ignore, Param_Cell, Param_Cell, Param_Float);
	
	h_fwdOnClientIgnite = CreateGlobalForward("ZR_OnClientIgnite", ET_Hook, Param_Cell, Param_Cell, Param_FloatByRef);
	h_fwdOnGrenadeEffect = CreateGlobalForward("ZR_OnGrenadeEffect", ET_Hook, Param_Cell, Param_Cell);
	h_fwdOnClientIgnited = CreateGlobalForward("ZR_OnClientIgnited", ET_Ignore, Param_Cell, Param_Cell, Param_Float);
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("zr_csgogreneffect_version", PLUGIN_VERSION, "The plugin's version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_CHEAT|FCVAR_DONTRECORD);

	g_Cvar_greneffects_enable = CreateConVar("zr_greneffect_enable", "1", "Enables/Disables the plugin", 0, true, 0.0, true, 1.0);
	g_Cvar_greneffects_trails = CreateConVar("zr_greneffect_trails", "1", "Enables/Disables Grenade Trails", 0, true, 0.0, true, 1.0);

	g_Cvar_greneffects_napalm_he = CreateConVar("zr_greneffect_napalm_he", "1", "Changes a he grenade to a napalm grenade", 0, true, 0.0, true, 1.0);
	g_Cvar_greneffects_napalm_he_duration = CreateConVar("zr_greneffect_napalm_he_duration", "6", "The napalm duration", 0, true, 0.0);

	g_Cvar_greneffects_smoke_freeze = CreateConVar("zr_greneffect_smoke_freeze", "1", "Changes a smoke grenade to a freeze grenade", 0, true, 0.0, true, 1.0);
	g_Cvar_greneffects_smoke_freeze_distance = CreateConVar("zr_greneffect_smoke_freeze_distance", "600", "The freeze grenade distance", 0, true, 100.0);
	g_Cvar_greneffects_smoke_freeze_duration = CreateConVar("zr_greneffect_smoke_freeze_duration", "4", "The freeze duration in seconds", 0, true, 1.0);
	g_Cvar_greneffects_smoke_freeze_icecube = CreateConVar("zr_greneffect_smoke_freeze_icecube", "1", "Enable ice cube", 0, true, 0.0, true, 1.0);
	g_Cvar_greneffects_smoke_freeze_snow = CreateConVar("zr_greneffect_smoke_freeze_snow", "1", "Enable Snow", 0, true, 0.0, true, 1.0);

	g_Cvar_greneffects_flash_light = CreateConVar("zr_greneffect_flash_light", "1", "Changes a flashbang to a flashlight", 0, true, 0.0, true, 1.0);
	g_Cvar_greneffects_flash_light_distance = CreateConVar("zr_greneffect_flash_light_distance", "1000", "The light distance", 0, true, 100.0);
	g_Cvar_greneffects_flash_light_duration = CreateConVar("zr_greneffect_flash_light_duration", "15.0", "The light duration in seconds", 0, true, 1.0);
	
	g_Cvar_greneffects_sound_freeze_enable = CreateConVar("zr_greneffect_sound_freeze_enable", "1", "Enable sound freeze.", 0, true, 0.0, true, 1.0);
	g_Cvar_greneffects_sound_unfreeze_enable = CreateConVar("zr_greneffect_sound_unfreeze_enable", "1", "Enable sound unfreeze.", 0, true, 0.0, true, 1.0);
	g_Cvar_greneffects_fire_Movement_Speed = CreateConVar("zr_greneffect_fire_Movement_Speed", "0.6", "Speed Applied to the zombie on fire.", 0, true, 1.0);

	b_enable = g_Cvar_greneffects_enable.BoolValue;
	b_trails = g_Cvar_greneffects_trails.BoolValue;
	b_napalm_he = g_Cvar_greneffects_napalm_he.BoolValue;
	f_napalm_he_duration = g_Cvar_greneffects_napalm_he_duration.FloatValue;
	b_smoke_freeze = g_Cvar_greneffects_smoke_freeze.BoolValue;
	b_flash_light = g_Cvar_greneffects_flash_light.BoolValue;
	f_smoke_freeze_distance = g_Cvar_greneffects_smoke_freeze_distance.FloatValue;
	f_smoke_freeze_duration = g_Cvar_greneffects_smoke_freeze_duration.FloatValue;
	b_icecube_enable = g_Cvar_greneffects_smoke_freeze_icecube.BoolValue;
	b_snow_enable = g_Cvar_greneffects_smoke_freeze_snow.BoolValue;
	f_flash_light_distance = g_Cvar_greneffects_flash_light_distance.FloatValue;
	f_flash_light_duration = g_Cvar_greneffects_flash_light_duration.FloatValue;
	b_snow_sound_freeze = g_Cvar_greneffects_sound_freeze_enable.BoolValue;
	b_snow_sound_unfreeze = g_Cvar_greneffects_sound_unfreeze_enable.BoolValue;
	f_fire_Movement_Speed = g_Cvar_greneffects_fire_Movement_Speed.FloatValue;

	g_Cvar_greneffects_enable.AddChangeHook(OnConVarChanged);
	g_Cvar_greneffects_trails.AddChangeHook(OnConVarChanged);
	g_Cvar_greneffects_napalm_he.AddChangeHook(OnConVarChanged);
	g_Cvar_greneffects_napalm_he_duration.AddChangeHook(OnConVarChanged);
	g_Cvar_greneffects_smoke_freeze.AddChangeHook(OnConVarChanged);
	g_Cvar_greneffects_smoke_freeze_distance.AddChangeHook(OnConVarChanged);
	g_Cvar_greneffects_smoke_freeze_duration.AddChangeHook(OnConVarChanged);
	g_Cvar_greneffects_smoke_freeze_icecube.AddChangeHook(OnConVarChanged);
	g_Cvar_greneffects_smoke_freeze_snow.AddChangeHook(OnConVarChanged);
	g_Cvar_greneffects_flash_light.AddChangeHook(OnConVarChanged);
	g_Cvar_greneffects_flash_light_distance.AddChangeHook(OnConVarChanged);
	g_Cvar_greneffects_flash_light_duration.AddChangeHook(OnConVarChanged);
	g_Cvar_greneffects_sound_freeze_enable.AddChangeHook(OnConVarChanged);
	g_Cvar_greneffects_sound_unfreeze_enable.AddChangeHook(OnConVarChanged);

	AutoExecConfig(true, "zombiereloaded/zr_grenade_effects_csgo");

	HookEvent("round_start", OnRoundEvent);
	HookEvent("round_end", OnRoundEvent);
	HookEvent("player_spawned", OnPlayerSpawned);
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("player_hurt", OnPlayerHurt);
	HookEvent("hegrenade_detonate", OnHeDetonate);

	AddNormalSoundHook(NormalSHook);

	for(int i = 1; i <= MaxClients; i++)
	{	
		if(IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
}

public void OnConVarChanged(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	b_enable = g_Cvar_greneffects_enable.BoolValue;
	b_trails = g_Cvar_greneffects_trails.BoolValue;
	b_napalm_he = g_Cvar_greneffects_napalm_he.BoolValue;
	f_napalm_he_duration = g_Cvar_greneffects_napalm_he_duration.FloatValue;
	b_smoke_freeze = g_Cvar_greneffects_smoke_freeze.BoolValue;
	b_flash_light = g_Cvar_greneffects_flash_light.BoolValue;
	f_smoke_freeze_distance = g_Cvar_greneffects_smoke_freeze_distance.FloatValue;
	f_smoke_freeze_duration = g_Cvar_greneffects_smoke_freeze_duration.FloatValue;
	b_icecube_enable = g_Cvar_greneffects_smoke_freeze_icecube.BoolValue;
	b_snow_enable = g_Cvar_greneffects_smoke_freeze_snow.BoolValue;
	f_flash_light_distance = g_Cvar_greneffects_flash_light_distance.FloatValue;
	f_flash_light_duration = g_Cvar_greneffects_flash_light_duration.FloatValue;
	b_snow_sound_freeze = g_Cvar_greneffects_sound_freeze_enable.BoolValue;
	b_snow_sound_unfreeze = g_Cvar_greneffects_sound_unfreeze_enable.BoolValue;
	f_fire_Movement_Speed = g_Cvar_greneffects_fire_Movement_Speed.FloatValue;
}

public void OnMapStart()
{
	BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
	GlowSprite = PrecacheModel("materials/sprites/blueglow1.vmt");
	g_beamsprite = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_halosprite = PrecacheModel("materials/sprites/halo.vmt");
	
	// Ice cube model
	AddFileToDownloadsTable("materials/models/weapons/eminem/ice_cube/ice_cube.vtf");
	AddFileToDownloadsTable("materials/models/weapons/eminem/ice_cube/ice_cube_normal.vtf");
	AddFileToDownloadsTable("materials/models/weapons/eminem/ice_cube/ice_cube.vmt");
	AddFileToDownloadsTable("models/weapons/eminem/ice_cube/ice_cube.phy");
	AddFileToDownloadsTable("models/weapons/eminem/ice_cube/ice_cube.vvd");
	AddFileToDownloadsTable("models/weapons/eminem/ice_cube/ice_cube.dx90.vtx");
	AddFileToDownloadsTable("models/weapons/eminem/ice_cube/ice_cube.mdl");
	PrecacheModel(ICE_CUBE_MODEL, true);
	
	// Snow effect
	PrecacheModel("materials/particle/snow.vmt",true);
	PrecacheModel("particle/snow.vmt",true);

	PrecacheSound(SOUND_FREEZE);
	PrecacheSound(SOUND_UNFREEZE);
	PrecacheSound(SOUND_FREEZE_EXPLODE);
}

public void OnClientDisconnect(int client)
{
	if (h_freeze_timer[client] != INVALID_HANDLE)
	{
		KillTimer(h_freeze_timer[client]);
		h_freeze_timer[client] = INVALID_HANDLE;
		if (b_icecube_enable && b_icecube_active[client]) IceCubeOff(client);
		if (b_snow_enable && b_snow_active[client]) SnowOff(client);
	}
	b_icecube_active[client] = false;
	b_snow_active[client] = false;

	if (h_timers_slow[client] != INVALID_HANDLE)
    {
		KillTimer(h_timers_slow[client]);
		h_timers_slow[client] = INVALID_HANDLE;
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(damagetype & DMG_BURN && IsPlayerAlive(client) && ZR_IsClientZombie(client))
	{
		if (h_timers_slow[client] == INVALID_HANDLE)
		{
			SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", f_fire_Movement_Speed);
			h_timers_slow[client] = CreateTimer(0.3, StopMovementSlow, client);
		}
		else
		{
			KillTimer(h_timers_slow[client]);
			h_timers_slow[client] = INVALID_HANDLE;
		
			SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", f_fire_Movement_Speed);
			h_timers_slow[client] = CreateTimer(0.3, StopMovementSlow, client);
		}
	}
}

public Action OnRoundEvent(Handle event, char[] name, bool dontBroadcast)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (h_freeze_timer[client] != INVALID_HANDLE)
		{
			KillTimer(h_freeze_timer[client]);
			h_freeze_timer[client] = INVALID_HANDLE;
			if (b_icecube_enable && b_icecube_active[client]) IceCubeOff(client);
			if (b_snow_enable && b_snow_active[client]) SnowOff(client);
		}
		b_icecube_active[client] = false;
		b_snow_active[client] = false;
	}
}

public Action OnPlayerSpawned(Handle event, char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (h_freeze_timer[client] != INVALID_HANDLE)
	{
		KillTimer(h_freeze_timer[client]);
		h_freeze_timer[client] = INVALID_HANDLE;
		if (b_icecube_enable && b_icecube_active[client]) IceCubeOff(client);
		if (b_snow_enable && b_snow_active[client]) SnowOff(client);
	}
	b_icecube_active[client] = false;
	b_snow_active[client] = false;
}

public Action OnPlayerHurt(Handle event, char[] name, bool dontBroadcast)
{
	if (!b_napalm_he)
	{
		return;
	}
	char g_szWeapon[32];
	GetEventString(event, "weapon", g_szWeapon, sizeof(g_szWeapon));
	
	if (!StrEqual(g_szWeapon, "hegrenade", false))
	{
		return;
	}
	
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (ZR_IsClientHuman(client))
	{
		return;
	}
	
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	Action result; 
	float dummy_duration = f_napalm_he_duration;
	result = Forward_OnClientIgnite(client, attacker, dummy_duration);
	
	switch (result)
	{
		case Plugin_Handled, Plugin_Stop :
		{
			return;
		}
		case Plugin_Continue :
		{
			dummy_duration = f_napalm_he_duration;
		}
	}

	IgniteEntity(client, dummy_duration);
	
	Forward_OnClientIgnited(client, attacker, dummy_duration);
}

public Action OnPlayerDeath(Handle event, char[] name, bool dontBroadcast)
{
	OnClientDisconnect(GetClientOfUserId(GetEventInt(event, "userid")));
}

public Action StopMovementSlow(Handle timer, any client)
{
	h_timers_slow[client] = INVALID_HANDLE;
	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		float velocidad = ZRT_GetClientAttributeValueFloat(client, "speed", 300.0);
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", velocidad/300.0);
	}
}

public Action OnHeDetonate(Handle event, char[] name, bool dontBroadcast) 
{
	if (!b_enable || !b_napalm_he)
	{
		return;
	}
	
	float origin[3];
	origin[0] = GetEventFloat(event, "x"); origin[1] = GetEventFloat(event, "y"); origin[2] = GetEventFloat(event, "z");
	
	TE_SetupBeamRingPoint(origin, 10.0, 400.0, g_beamsprite, g_halosprite, 1, 1, 0.2, 100.0, 1.0, FragColor, 0, 0);
	TE_SendToAll();
}
	
public Action GranadaCongela(int client, float origin[3])
{
	origin[2] += 10.0;
	
	float targetOrigin[3];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || ZR_IsClientHuman(i))
		{
			continue;
		}
		
		GetClientAbsOrigin(i, targetOrigin);
		targetOrigin[2] += 2.0;
		if (GetVectorDistance(origin, targetOrigin) <= f_smoke_freeze_distance)
		{
			Handle trace = TR_TraceRayFilterEx(origin, targetOrigin, MASK_SOLID, RayType_EndPoint, FilterTarget, i);
		
			if ((TR_DidHit(trace) && TR_GetEntityIndex(trace) == i) || (GetVectorDistance(origin, targetOrigin) <= 100.0))
			{
				Freeze(i, client, f_smoke_freeze_duration);
				CloseHandle(trace);
			}
				
			else
			{
				CloseHandle(trace);
				
				GetClientEyePosition(i, targetOrigin);
				targetOrigin[2] -= 2.0;
		
				trace = TR_TraceRayFilterEx(origin, targetOrigin, MASK_SOLID, RayType_EndPoint, FilterTarget, i);
			
				if ((TR_DidHit(trace) && TR_GetEntityIndex(trace) == i) || (GetVectorDistance(origin, targetOrigin) <= 100.0))
				{
					Freeze(i, client, f_smoke_freeze_duration);
				}
				
				CloseHandle(trace);
			}
		}
	}
	
	TE_SetupBeamRingPoint(origin, 10.0, f_smoke_freeze_distance, g_beamsprite, g_halosprite, 1, 1, 0.2, 100.0, 1.0, FreezeColor, 0, 0);
	TE_SendToAll();
	LightCreate(SMOKE, origin);
}

public bool FilterTarget(int entity, int contentsMask, any data)
{
	return (data == entity);
}

public Action DoFlashLight(Handle timer, any entity)
{
	if (!IsValidEdict(entity))
	{
		return Plugin_Stop;
	}
		
	char g_szClassname[64];
	GetEdictClassname(entity, g_szClassname, sizeof(g_szClassname));
	if (!strcmp(g_szClassname, "flashbang_projectile", false))
	{
		float origin[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
		origin[2] += 50.0;
		LightCreate(FLASH, origin);
		AcceptEntityInput(entity, "kill");
	}
	
	return Plugin_Stop;
}

public bool Freeze(int client, int attacker, float &time)
{
	Action result;
	float dummy_duration = time;
	result = Forward_OnClientFreeze(client, attacker, dummy_duration);
	
	switch (result)
	{
		case Plugin_Handled, Plugin_Stop :
		{
			return false;
		}
		case Plugin_Continue :
		{
			dummy_duration = time;
		}
	}
	
	if (h_freeze_timer[client] != INVALID_HANDLE)
	{
		KillTimer(h_freeze_timer[client]);
		h_freeze_timer[client] = INVALID_HANDLE;
		if (b_icecube_enable && b_icecube_active[client]) IceCubeOff(client);
		if (b_snow_enable && b_snow_active[client]) SnowOff(client);
	}
	
	SetEntityMoveType(client, MOVETYPE_NONE);
	float vec[3];
	GetClientEyePosition(client, vec);
	vec[2] -= 50.0;

	if (b_icecube_enable)
	{
		CreateIceCube(client);
	}
	else
	{
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, NULL_VELOCITY);
		TE_SetupGlowSprite(vec, GlowSprite, dummy_duration, 2.0, 50);
		TE_SendToAll();
	}

	if (b_snow_sound_freeze)
	EmitSoundToAll(SOUND_FREEZE, SOUND_FROM_WORLD, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, vec);
	
	if(b_snow_enable)	CreateSnow(client);
	
	h_freeze_timer[client] = CreateTimer(dummy_duration, Unfreeze, client, TIMER_FLAG_NO_MAPCHANGE);
	
	Forward_OnClientFreezed(client, attacker, dummy_duration);
	
	return true;
}

void CreateIceCube(int client)
{
	int model = CreateEntityByName("prop_dynamic_override");
	if(model == -1) return;

	float AbsOrigin[3];
	GetClientAbsOrigin(client, AbsOrigin);

	DispatchKeyValue(model, "model", ICE_CUBE_MODEL);
	DispatchKeyValue(model, "spawnflags", "256");
	DispatchKeyValue(model, "solid", "0");
	SetEntPropEnt(model, Prop_Send, "m_hOwnerEntity", client);

	DispatchSpawn(model);

	TeleportEntity(model, AbsOrigin, NULL_VECTOR, NULL_VELOCITY);

	SetVariantString("!activator");
	AcceptEntityInput(model, "SetParent", client, model, 0);

	AcceptEntityInput(model, "TurnOn", model, model, 0);

	IceRef[client] = EntIndexToEntRef(model);
	b_icecube_active[client] = true;
}

void CreateSnow(int client)
{
	int ent = CreateEntityByName("env_smokestack");
	if(ent == -1) return;
	
	float eyePosition[3];
	GetClientEyePosition(client, eyePosition);
	
	eyePosition[2] +=25.0;
	DispatchKeyValueVector(ent,"Origin", eyePosition);
	DispatchKeyValueFloat(ent,"BaseSpread", 50.0);
	DispatchKeyValue(ent,"SpreadSpeed", "100");
	DispatchKeyValue(ent,"Speed", "25");
	DispatchKeyValueFloat(ent,"StartSize", 1.0);
	DispatchKeyValueFloat(ent,"EndSize", 1.0);
	DispatchKeyValue(ent,"Rate", "125");
	DispatchKeyValue(ent,"JetLength", "300");
	DispatchKeyValueFloat(ent,"Twist", 200.0);
	DispatchKeyValue(ent,"RenderColor", "255 255 255");
	DispatchKeyValue(ent,"RenderAmt", "200");
	DispatchKeyValue(ent,"RenderMode", "18");
	DispatchKeyValue(ent,"SmokeMaterial", "particle/snow");
	DispatchKeyValue(ent,"Angles", "180 0 0");
	
	DispatchSpawn(ent);
	ActivateEntity(ent);
	
	eyePosition[2] += 50;
	TeleportEntity(ent, eyePosition, NULL_VECTOR, NULL_VECTOR);
	
	SetVariantString("!activator");
	AcceptEntityInput(ent, "SetParent", client);
	
	AcceptEntityInput(ent, "TurnOn");
	
	SnowRef[client] = EntIndexToEntRef(ent);
	b_snow_active[client] = true;
}

public Action Unfreeze(Handle timer, any client)
{
	if (h_freeze_timer[client] != INVALID_HANDLE)
	{
		float vec[3];
		GetClientEyePosition(client, vec);
		vec[2] -= 50.0;

		SetEntityMoveType(client, MOVETYPE_WALK);
		h_freeze_timer[client] = INVALID_HANDLE;

		if (b_icecube_enable && b_icecube_active[client]) IceCubeOff(client);
		if (b_snow_enable && b_snow_active[client]) SnowOff(client);

		if (b_snow_sound_unfreeze)
		EmitSoundToAll(SOUND_UNFREEZE, SOUND_FROM_WORLD, SNDCHAN_AUTO, SNDLEVEL_HOME, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, vec);
	}
}

void SnowOff(int client)
{ 
	int entity = EntRefToEntIndex(SnowRef[client]);
	if(entity != INVALID_ENT_REFERENCE && IsValidEdict(entity) && entity != 0)
	{
		AcceptEntityInput(entity, "TurnOff"); 
		AcceptEntityInput(entity, "Kill"); 
		SnowRef[client] = INVALID_ENT_REFERENCE;
		b_snow_active[client] = false;
	}
}

void IceCubeOff(int client)
{ 
	int entity = EntRefToEntIndex(IceRef[client]);
	if(entity != INVALID_ENT_REFERENCE && IsValidEdict(entity) && entity != 0)
	{
		AcceptEntityInput(entity, "TurnOff"); 
		AcceptEntityInput(entity, "Kill"); 
		IceRef[client] = INVALID_ENT_REFERENCE;
		b_icecube_active[client] = false;
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrContains(classname, "_projectile") != -1) SDKHook(entity, SDKHook_SpawnPost, Grenade_SpawnPost);
	
}

public Action Grenade_SpawnPost(int entity)
{
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (client == -1)return;
	
	Action result;
	result = Forward_OnGrenadeEffect(client, entity);
	
	switch (result)
	{
		case Plugin_Handled, Plugin_Stop:
		{
			return;
		}
	}
	
	if (!b_enable)
	{
		return;
	}
	
	char classname[64];
	GetEdictClassname(entity, classname, 64);
	
	if (!strcmp(classname, "hegrenade_projectile"))
	{
		BeamFollowCreate(entity, FragColor);
		if (b_napalm_he)
		{
			IgniteEntity(entity, 2.0);
		}
	}
 	else if (!strcmp(classname, "flashbang_projectile"))
	{
		if (b_flash_light)
		{
			CreateTimer(1.3, DoFlashLight, entity, TIMER_FLAG_NO_MAPCHANGE);
		}
		BeamFollowCreate(entity, FlashColor);
	} 
	else if (!strcmp(classname, "smokegrenade_projectile") || !strcmp(classname, "decoy_projectile"))
	{
		if (b_smoke_freeze)
		{
			BeamFollowCreate(entity, FreezeColor);
			CreateTimer(1.3, CreateEvent_SmokeDetonate, entity, TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			BeamFollowCreate(entity, SmokeColor);
		}
		int iReference = EntIndexToEntRef(entity);
		CreateTimer(0.1, Timer_OnGrenadeCreated, iReference);
	}
}

public Action Timer_OnGrenadeCreated(Handle timer, any ref)
{
    int entity = EntRefToEntIndex(ref);
    if(entity != INVALID_ENT_REFERENCE)
    {
            SetEntProp(entity, Prop_Data, "m_nNextThinkTick", -1);
    }
}

public Action CreateEvent_SmokeDetonate(Handle timer, any entity)
{
	if (!IsValidEdict(entity))
	{
		return Plugin_Stop;
	}
	
	char g_szClassname[64];
	GetEdictClassname(entity, g_szClassname, sizeof(g_szClassname));
	if (!strcmp(g_szClassname, "smokegrenade_projectile", false) || !strcmp(g_szClassname, "decoy_projectile", false))
	{
		float origin[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
		int client = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
		GranadaCongela(client, origin);
		AcceptEntityInput(entity, "kill");
	}
	
	return Plugin_Stop;
}

public Action BeamFollowCreate(int entity, int color[4])
{
	if (b_trails)
	{
		TE_SetupBeamFollow(entity, BeamSprite,	0, 1.0, 10.0, 10.0, 5, color);
		TE_SendToAll();	
	}
}

public Action LightCreate(int grenade, float pos[3])   
{  
	int  iEntity = CreateEntityByName("light_dynamic");
	DispatchKeyValue(iEntity, "inner_cone", "0");
	DispatchKeyValue(iEntity, "cone", "80");
	DispatchKeyValue(iEntity, "brightness", "1");
	DispatchKeyValueFloat(iEntity, "spotlight_radius", 150.0);
	DispatchKeyValue(iEntity, "pitch", "90");
	DispatchKeyValue(iEntity, "style", "1");
	switch(grenade)
	{
		case FLASH : 
		{
			DispatchKeyValue(iEntity, "_light", "255 255 255 255");
			DispatchKeyValueFloat(iEntity, "distance", f_flash_light_distance);

			EmitSoundToAll("items/nvg_on.wav", SOUND_FROM_WORLD, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, pos);
			CreateTimer(f_flash_light_duration, Delete, iEntity, TIMER_FLAG_NO_MAPCHANGE);
		}
		case SMOKE : 
		{
			DispatchKeyValue(iEntity, "_light", "75 75 255 255");
			DispatchKeyValueFloat(iEntity, "distance", f_smoke_freeze_distance);

			EmitSoundToAll(SOUND_FREEZE_EXPLODE, SOUND_FROM_WORLD, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, pos);
			CreateTimer(0.2, Delete, iEntity, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	DispatchSpawn(iEntity);
	TeleportEntity(iEntity, pos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(iEntity, "TurnOn");
}

public Action Delete(Handle timer, any entity)
{
	if (IsValidEdict(entity))
	{
		AcceptEntityInput(entity, "kill");
	}
}

public Action NormalSHook(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	if (b_smoke_freeze && !strcmp(sample, "^weapons/smokegrenade/sg_explode.wav"))
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

/*
		F O R W A R D S
	------------------------------------------------
*/

Action Forward_OnGrenadeEffect(int client, int entity)
{
	Action result;
	result = Plugin_Continue;
	
	Call_StartForward(h_fwdOnGrenadeEffect);
	Call_PushCell(client);
	Call_PushCell(entity);
	Call_Finish(result);
	
	return result;
}

Action Forward_OnClientFreeze(int client, int attacker, float &time)
{
	Action result;
	result = Plugin_Continue;
	
	Call_StartForward(h_fwdOnClientFreeze);
	Call_PushCell(client);
	Call_PushCell(attacker);
	Call_PushFloatRef(time);
	Call_Finish(result);
	
	return result;
}

Action Forward_OnClientFreezed(int client, int attacker, float time)
{
	Call_StartForward(h_fwdOnClientFreezed);
	Call_PushCell(client);
	Call_PushCell(attacker);
	Call_PushFloat(time);
	Call_Finish();
}

Action Forward_OnClientIgnite(int client, int attacker, float &time)
{
	Action result;
	result = Plugin_Continue;
	
	Call_StartForward(h_fwdOnClientIgnite);
	Call_PushCell(client);
	Call_PushCell(attacker);
	Call_PushFloatRef(time);
	Call_Finish(result);
	
	return result;
}

Action Forward_OnClientIgnited(int client, int attacker, float time)
{
	Call_StartForward(h_fwdOnClientIgnited);
	Call_PushCell(client);
	Call_PushCell(attacker);
	Call_PushFloat(time);
	Call_Finish();
}