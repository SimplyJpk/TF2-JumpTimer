/* A Collection of methods that do not really fit in anywhere else. */

// 1101 Base Jumper
// Primary
// 730 Beggars
// 414 Liberty
// 1104 AirStrike
// Secondary
// 131 Chargin' Targe
// 406 Splendid Screen
// 1099 Tide turner
// 1144 Festive Targe
// 444 Mantreads
// 133 Gunboats
// Melee
// 307 Caber
// 775 Escape Plan
// 447 Disciplinary Action
int Blocked_Weapons[WeaponCheckTypes][7] =  {
	{ 1101, 730, 414, 1104 }, 
	{ 1101, 444, 133, 131, 406, 1099, 1144 }, 
	{ 447, 775, 307 } };

// Destroy Engineer Stuff
char Engineer_Buildings[][] =  { "obj_teleporter", "obj_sentrygun", "obj_dispenser" };
void DestroyBuildings(client)
{
	int iEnt = -1;
	bool _destroyed = false;
	for (int i = 0; i < sizeof(Engineer_Buildings); i++)
	{
		while ((iEnt = FindEntityByClassname(iEnt, Engineer_Buildings[i])) != INVALID_ENT_REFERENCE)
		{
			if (GetEntPropEnt(iEnt, Prop_Send, "m_hBuilder") == client)
			{
				SetVariantInt(1000);
				AcceptEntityInput(iEnt, "RemoveHealth");
				_destroyed = true;
			}
		}
	}
	if (_destroyed)
		CPrintToChat(client, "%s {RED} Buildings Destroyed.", ChatTag);
} 

void ClearUserWeps(int client)
{
	for (int i = 0; i < WeaponCheckCount; i++)
	{
		USER_Weapons[client][i] = -1;
	}
}