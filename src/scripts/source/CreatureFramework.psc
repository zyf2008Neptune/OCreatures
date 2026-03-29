Scriptname CreatureFramework extends Quest
{The framework script to interact with | Creature Framework}

; General properties
CFConfigMenu property Config auto hidden
Armor property FakeSkin auto
Keyword property ArmorNormalKeyword auto
Keyword property ArmorArousedKeyword auto
Keyword property AnimalKeyword auto
Keyword property CreatureKeyword auto
Keyword property DwarvenKeyword auto
; EDIT----------------------------------------------------------------------------------------
;
;SexLabFramework property SexLab auto hidden
slaUtilScr property SexLabAroused auto hidden
;
; EDIT----------------------------------------------------------------------------------------
Faction property ArousedFaction auto hidden
Spell property TargetPuppetSpell auto
Quest Property Detect Auto
Actor Property Player Auto
int AltStartMod = 0

;Keyword SLActive
Actor[] ACreatures
Int[] AFlags ; 0=notaroused, 1=aroused.
Int[] ACreaturesMaps
bool rcGuard = false

; The currently installed version
int version = 0

; JContainers
int jMainMap = -1
int jModsMap = -1
int jRacesMap = -1
int jSkinsMap = -1
int jCreaturesMap = -1
int jEventsMap = -1
int jLoadedFiles = -1

; Registration types
string[] types

; Armour slots
int[] armorSlots
string[] arousalSources

; Whether or not the active actors are being restarted
bool restartingActiveActors = false

; Whether or not we're in the middle of parsing the JSON files
bool loadingJSON = false

; Counter for how many things are telling us to prevent mucking about
int muckingAboutPreventor = 0

Actor puppet

; Initialise (needs to be run on each startup)
function Initialize()
	muckingAboutPreventor += 1
	Config = CreatureFrameworkUtil.GetConfig()
	UnregisterForAllModEvents()

	; Validate JContainers version
	if JContainers.APIVersion() >= 3 && JContainers.IsInstalled()
	else
		CFDebug.Log("[Framework] Aborting initialisation")
		Debug.MessageBox("Creature Framework's startup initialisation has failed, please make sure JContainers is installed and running correctly.")
		return
	endIf
	if Game.GetModByName("Skyrim Unbound.esp") != 255 || Game.GetModByName("Realm of Lorkhan - Custom Alternate Start - Choose your own adventure.esp") != 255 || Game.GetModByName("Alternate Start - Live Another Life.esp") != 255 || Game.GetModByName("AlternatePerspective.esp") != 255
		AltStartMod = 1
	endIf
	; Obtain the main container
	jMainMap = JDB.SolveObj(".CreatureFramework")
	if jMainMap == 0
		jMainMap = JMap.Object()
		JDB.SetObj("CreatureFramework", jMainMap)
	endIf

	; Initialise the containers
	jModsMap = InitializeContainer("mods", 0)
	jRacesMap = InitializeContainer("races", 1)
	jSkinsMap = InitializeContainer("skins", 1)
	jCreaturesMap = InitializeContainer("creatures", 1)
	jEventsMap = InitializeContainer("events", 0)
	jLoadedFiles = InitializeContainer("loadedFiles", 2)

	; Set registration types
	types = new string[3]
	types[0] = "events"
	types[1] = "armors"
	types[2] = "both"

	; Set armour slots
	armorSlots = new int[6]
	armorSlots[0] = 0x00000001 ; Head
	armorSlots[1] = 0x00000004 ; Body
	armorSlots[2] = 0x00000008 ; Hands
	armorSlots[3] = 0x00000080 ; Feet
	armorSlots[4] = 0x00000040 ; Ring (for vampire lords)
	armorSlots[5] = 0x00000020 ; Amulet (for vampire lords)

	; Set arousal sources
	arousalSources = new string[3]
	arousalSources[0] = "$None"
;EDIT----------------------------------------------------------------------------------------
	;arousalSources[1] = "$SexLab animation"
	arousalSources[1] = "$Ostim animation"
;EDIT----------------------------------------------------------------------------------------
	arousalSources[2] = "$SexLab Aroused"
	
	; Get soft dependencies
;EDIT----------------------------------------------------------------------------------------
	;if Game.GetModByName("SexLab.esm") != 255
	;	SexLab = SexLabUtil.GetAPI()
	;else
	;	SexLab = none
	;endIf
;EDIT----------------------------------------------------------------------------------------
	if Game.GetModByName("SexLabAroused.esm") != 255
		SexLabAroused = Game.GetFormFromFile(0x4290F, "SexLabAroused.esm") as slaUtilScr
		if SexLabAroused
			ArousedFaction = SexLabAroused.slaArousal
		else
			ArousedFaction = none
		endIf
	else
		SexLabAroused = none
		ArousedFaction = none
	endIf

	if !UnboundQ || UnboundQ == none
		UnboundQ = Quest.GetQuest("MQ101")
	endIf
	
	; Deal with Form DB keys on v2 and below
	if version <= 20000 && version != 0
		; Transfer old Form DB to new key
		if JDB.SolveObj(".CFForm") == 0
			CFDebug.Log("[Framework] Transferring .CreatureFrameworkForm to .CFForm in JDB")
			JDB.SetObj("CFForm", JDB.SolveObj(".CreatureFrameworkForm"))
		endIf

		; Wipe out old ones
		if JDB.SolveObj(".CreatureFrameworkFormLog") != 0
			CFDebug.Log("[Framework] Wiping out old JDB keys")
			JDB.SetObj("CreatureFrameworkForm", 0)
			JDB.SetObj("CreatureFrameworkFormLog", 0)
		endIf
	endIf
	
	; Display version notification
	Int t = CreatureFrameworkUtil.GetVersion()
	if version == 0
		CFDebug.Log("[Framework] Installed")
		Debug.Notification("$CF_InstallNotification")
	elseIf version < t
		CFDebug.Log("[Framework] Upgraded from version " + version)
		Debug.Notification("$CF_UpdateNotification")
	elseIf version > t
		CFDebug.Log("[Framework] Downgraded from version " + version)
		CFDebug.Log("[Framework] Aborting initialisation")
		Debug.MessageBox("Creature Framework has been downgraded to " + GetVersionString() + ". Things will be broken!")
		return
	endIf
	version = t
	
	ACreatures = new Actor[32]
	AFlags = new Int[32]
	ACreaturesMaps = new Int[32]
	rcGuard = true
	Utility.Wait(3)
	SendRegisterEvent()
	Utility.Wait(2)
	LoadJSONRegistrations()
	RestartActiveActors()
	rcGuard = false
	muckingAboutPreventor -= 1
	if muckingAboutPreventor < 0
		muckingAboutPreventor = 0
	endIf
	; Register for the puppet target key
	UnregisterForAllKeys()
	RegisterForKey(Config.PupTargetKey)
;EDIT----------------------------------------------------------------------------------------
;	RegisterForModEvent("AnimationStart", "OnSexLabAnimationStart")
;	RegisterForModEvent("AnimationEnd", "OnSexLabAnimationEnd")
;	RegisterForModEvent("ActorChangeStart", "OnSexLabAnimationEnd")
;	RegisterForModEvent("ActorChangeEnd", "OnSexLabAnimationStart")
	RegisterForModEvent("ostim_thread_start", "OnOstimAnimationStart")
	RegisterForModEvent("ostim_thread_end", "OnOstimAnimationEnd")
;EDIT----------------------------------------------------------------------------------------
	RegisterForModEvent("slaUpdateExposure", "OnModifyExposure")

	RegisterForSingleUpdate(Config.PrfTimeout)
	CFDebug.Log("[Framework] Creature Framework is done initialising")
endFunction

; Initialize a container if necessary; type 0 = JMap, 1 = JFormMap, 2 = JArray
int function InitializeContainer(string containerKey, int containerType)
	if JMap.ValueType(jMainMap, containerKey) == 5
		return JMap.GetObj(jMainMap, containerKey)
	else
		CFDebug.Log("[Framework] Data map is missing \"" + containerKey + "\"; initialising")
		int obj
		if containerType == 0
			obj = JMap.Object()
		elseIf containerType == 1
			obj = JFormMap.Object()
		elseIf containerType == 2
			obj = JArray.Object()
		endIf
		JMap.SetObj(jMainMap, containerKey, obj)
		return obj
	endIf
endFunction

; The puppet target key was changed
function PuppetTargetKeyChange()
	UnregisterForAllKeys()
	RegisterForKey(Config.PupTargetKey)
Endfunction

; A key has been released
event OnKeyUp(int keyCode, float holdTime)
	if keyCode == Config.PupTargetKey
		TargetPuppetSpell.Cast(Player)
	endIf
endEvent

Function Uninstall()
	UnregisterForUpdate()
	UnregisterForAllKeys()
	ClearCreatures()
	UnregisterAllMods()
	ClearFormDB()
Endfunction
;----------------------------------------------------------------
; Mod-related methods						|
;----------------------------------------------------------------

; Register a mod to the framework
function RegisterMod(string modId, string modName)
	; Create the map for the mod and add it
	int modMap = JMap.Object()
	JMap.SetStr(modMap, "name", modName)
	JMap.SetObj(modMap, "races", JArray.Object())
	JMap.SetObj(modMap, "skins", JArray.Object())
	JMap.SetObj(jModsMap, modId, modMap)
	CFDebug.Log("[Framework] Registered mod with ID \"" + modId + "\" and name \"" + modName + "\"")
endFunction

; Unregister a mod from the framework
function UnregisterMod(string modId)
	UnregisterAllCreaturesFromMod(modId)
	JMap.RemoveKey(jModsMap, modId)
	CFDebug.Log("[Framework] Unregistered mod with ID \"" + modId + "\"")
endFunction

; Unregister all mods from the framework
function UnregisterAllMods()
	JMap.Clear(jModsMap)
	JFormMap.Clear(jCreaturesMap)
	JFormMap.Clear(jRacesMap)
	JFormMap.Clear(jSkinsMap)
	CFDebug.Log("[Framework] Unregistered all mods")
endFunction

; Unregister all mods and send the register event
function ReregisterAllMods()
	if !muckingAboutPreventor
		muckingAboutPreventor += 1
		CFDebug.Log("[Framework] Reregistering all mods")
		UnregisterAllMods()
		SendRegisterEvent()
		ResetLoadedFiles()
		LoadJSONRegistrations()
		muckingAboutPreventor -= 1
		if muckingAboutPreventor < 0
			muckingAboutPreventor = 0
		endIf
	endIf
endFunction

; Get a JArray of all of the registered mod IDs
int function GetRegisteredMods()
	return JMap.AllKeys(jModsMap)
endFunction

; Test to see if a mod is registered
bool function IsModRegistered(string modId)
	return JMap.HasKey(jModsMap, modId)
endFunction

; Get a mod's name
string function GetModName(string modId)
	return JMap.GetStr(JMap.GetObj(jModsMap, modId), "name")
endFunction

; Send the register event
function SendRegisterEvent()
	int handle = ModEvent.Create("CFRegister")
	if handle
		CFDebug.Log("[Framework] Sending register event")
		ModEvent.PushForm(handle, self)
		ModEvent.Send(handle)
	else
		CFDebug.Log("[Framework] Unable to send register event; invalid handle")
	endIf
endFunction


;----------------------------------------------------------------
; Creature-related methods					|
;----------------------------------------------------------------

; Register a creature to a mod
function RegisterCreatureToMod(string modId, Race raceForm, Armor skinForm, string raceName, string skinName, int type, Armor normalArmor = none, Armor arousedArmor = none, bool stripArmor = false, bool stripWeapons = true, Form[] stripFormBlacklist = none, int[] stripSlotBlacklist = none, int[] restrictedSlots = none)
	Armor realSkin
	if skinForm
		realSkin = skinForm
	else
		realSkin = FakeSkin
	endif
	if IsModRegistered(modId)
		if type >= 0 && type < types.length
			; Add the race/skin to all the relevant maps
			if !IsRaceRegistered(raceForm)
				if raceName == ""
					raceName = raceForm.GetName()
				endIf

				int jRaceMap = JMap.Object()
				JMap.SetStr(jRaceMap, "name", raceName)
				JMap.SetObj(jRaceMap, "mods", JArray.Object())
				JMap.SetObj(jRaceMap, "skins", JArray.Object())
				JFormMap.SetObj(jRacesMap, raceForm, jRaceMap)
				JFormMap.SetObj(jCreaturesMap, raceForm, JFormMap.Object())
				CFDebug.Log("[Framework] Added race " + CreatureFrameworkUtil.GetDetailedFormName(raceForm))
			endIf
			if !IsCreatureRegistered(raceForm, realSkin, false)
				if realSkin == FakeSkin
					skinName = ""
				endIf

				int jCreatureMap = JMap.Object()
				JMap.SetStr(jCreatureMap, "activeMod", modId)
				JMap.SetObj(jCreatureMap, "mods", JMap.Object())
				JFormMap.SetObj(JFormMap.GetObj(jCreaturesMap, raceForm), realSkin, jCreatureMap)

				JArray.AddForm(JMap.GetObj(JFormMap.GetObj(jRacesMap, raceForm), "skins"), realSkin)

				int jSkinMap = JMap.Object()
				JMap.SetStr(jSkinMap, "name", skinName)
				JMap.SetObj(jSkinMap, "mods", JArray.Object())
				JFormMap.SetObj(jSkinsMap, realSkin, jSkinMap)
				CFDebug.Log("[Framework] Added skin " + CreatureFrameworkUtil.GetDetailedFormName(realSkin) + " to race " + CreatureFrameworkUtil.GetDetailedFormName(raceForm))
			endIf

			; Add the race and skin to the mod and the mod to the race and skin
			if !IsRaceRegisteredToMod(modId, raceForm)
				JArray.AddForm(JMap.GetObj(JMap.GetObj(jModsMap, modId), "races"), raceForm)
				int jRaceModsMap = JMap.GetObj(JFormMap.GetObj(jRacesMap, raceForm), "mods")
				if JArray.FindStr(jRaceModsMap, modId) == -1
					JArray.AddStr(jRaceModsMap, modId)
				endIf
			endIf
			if !IsSkinRegisteredToMod(modId, realSkin)
				JArray.AddForm(JMap.GetObj(JMap.GetObj(jModsMap, modId), "skins"), realSkin)
				JArray.AddStr(JMap.GetObj(JFormMap.GetObj(jSkinsMap, realSkin), "mods"), modId)
				int jSkinModsMap = JMap.GetObj(JFormMap.GetObj(jSkinsMap, realSkin), "mods")
				if JArray.FindStr(jSkinModsMap, modId) == -1
					JArray.AddStr(jSkinModsMap, modId)
				endIf
			endIf

			; Create and add the mod map for the creature
			int jCreatureModMap = JMap.Object()
			JMap.SetInt(jCreatureModMap, "type", type)
			if type == 1 || type == 2
				JMap.SetForm(jCreatureModMap, "normalArmor", normalArmor)
				JMap.SetForm(jCreatureModMap, "arousedArmor", arousedArmor)
			endIf
			JMap.SetInt(jCreatureModMap, "stripArmor", stripArmor as int)
			JMap.SetInt(jCreatureModMap, "stripWeapons", stripWeapons as int)
			JMap.SetObj(jCreatureModMap, "stripFormBlacklist", CreatureFrameworkUtil.JArrayObjectFromForms(stripFormBlacklist))
			JMap.SetObj(jCreatureModMap, "stripSlotBlacklist", JArray.ObjectWithInts(stripSlotBlacklist))
			JMap.SetObj(jCreatureModMap, "restrictedSlots", JArray.ObjectWithInts(restrictedSlots))
			JMap.SetObj(JMap.GetObj(JFormMap.GetObj(JFormMap.GetObj(jCreaturesMap, raceForm), realSkin), "mods"), modId, jCreatureModMap)
			CFDebug.Log("[Framework] Registered " + CreatureFrameworkUtil.GetDetailedFormName(raceForm) + CreatureFrameworkUtil.GetDetailedFormName(realSkin) + " " + types[type] + " to mod \"" + modId + "\"")
		endIf
	endIf
endFunction

; Register a creature to a mod using the events type
string function RegisterCreatureEventsToMod(string modId, Race raceForm, Armor skinForm, string raceName, string skinName, bool stripArmor = true, bool stripWeapons = true, Form[] stripFormBlacklist = none, int[] stripSlotBlacklist = none, int[] restrictedSlots = none)
	RegisterCreatureToMod(modId, raceForm, skinForm, raceName, skinName, 0, none, none, stripArmor, stripWeapons, stripFormBlacklist, stripSlotBlacklist, restrictedSlots)
	return "CFArousalChange_" + modId
endFunction

; Register a creature to a mod using the swap type
function RegisterCreatureArmorSwapToMod(string modId, Race raceForm, Armor skinForm, string raceName, string skinName, Armor normalArmor, Armor arousedArmor = none, bool stripArmor = true, bool stripWeapons = true, Form[] stripFormBlacklist = none, int[] stripSlotBlacklist = none, int[] restrictedSlots = none)
	RegisterCreatureToMod(modId, raceForm, skinForm, raceName, skinName, 1, normalArmor, arousedArmor, stripArmor, stripWeapons, stripFormBlacklist, stripSlotBlacklist, restrictedSlots)
endFunction

; Register a creature to a mod using both a swap and event
string function RegisterCreatureArmorSwapAndEventsToMod(string modId, Race raceForm, Armor skinForm, string raceName, string skinName, Armor normalArmor, Armor arousedArmor = none, bool stripArmor = true, bool stripWeapons = true, Form[] stripFormBlacklist = none, int[] stripSlotBlacklist = none, int[] restrictedSlots = none)
	RegisterCreatureToMod(modId, raceForm, skinForm, raceName, skinName, 2, normalArmor, arousedArmor, stripArmor, stripWeapons, stripFormBlacklist, stripSlotBlacklist, restrictedSlots)
	return "CFArousalChange_" + modId
endFunction

; Unregister all creatures from a mod
function UnregisterAllCreaturesFromMod(string modId)
	; Clear the active mod of creatures that have it set to this one
	ClearActiveForMod(modId)

	; Clear the mod's races and skins
	JArray.Clear(JMap.GetObj(JMap.GetObj(jModsMap, modId), "races"))
	JArray.Clear(JMap.GetObj(JMap.GetObj(jModsMap, modId), "skins"))

	; Remove the mod from all creatures
	Form cr = JFormMap.NextKey(jCreaturesMap)
	while cr
		int jCreatureRaceMap = JFormMap.GetObj(jCreaturesMap, cr)
		Form cs = JFormMap.NextKey(jCreatureRaceMap)
		while cs
			int jCreatureMap = JFormMap.GetObj(jCreatureRaceMap, cs)
			JMap.RemoveKey(JMap.GetObj(jCreatureMap, "mods"), modId)
			cs = JFormMap.NextKey(jCreatureRaceMap, cs)
		endWhile
		cr = JFormMap.NextKey(jCreaturesMap, cr)
	endWhile

	; Remove the mod from all races
	Form r = JFormMap.NextKey(jRacesMap)
	while r
		int jRaceMap = JFormMap.GetObj(jRacesMap, r)
		int jRaceModsArr = JMap.GetObj(jRaceMap, "mods")
		JArray.EraseIndex(jRaceModsArr, JArray.FindStr(jRaceModsArr, modId))
		r = JFormMap.NextKey(jRacesMap, r)
	endWhile

	; Remove the mod from all skins
	Form s = JFormMap.NextKey(jSkinsMap)
	while s
		int jSkinMap = JFormMap.GetObj(jSkinsMap, s)
		int jSkinModsArr = JMap.GetObj(jSkinMap, "mods")
		JArray.EraseIndex(jSkinModsArr, JArray.FindStr(jSkinModsArr, modId))
		s = JFormMap.NextKey(jSkinsMap, s)
	endWhile
		CFDebug.Log("[Framework] Unregistered all creatures from mod ID \"" + modId + "\"")
endFunction

; Get the JFormMap of all registered creatures
int function GetRegisteredCreatures()
	return jCreaturesMap
endFunction

; Test to see if a creature is registered (will still return true if the FakeSkin is registered, but the specified skin isn't)
bool function IsCreatureRegistered(Race raceForm, Armor skinForm, bool checkFake = true)
	return JFormMap.HasKey(jCreaturesMap, raceForm) && (JFormMap.HasKey(JFormMap.GetObj(jCreaturesMap, raceForm), GetSkinOrFake(skinForm)) || (checkFake && JFormMap.HasKey(JFormMap.GetObj(jCreaturesMap, raceForm), FakeSkin)))
endFunction

; Test to see if an exact creature is registered (will not return true if the FakeSkin is registered, but the specified skin isn't)
bool function IsExactCreatureRegistered(Race raceForm, Armor skinForm)
	return JFormMap.HasKey(jCreaturesMap, raceForm) && JFormMap.HasKey(JFormMap.GetObj(jCreaturesMap, raceForm), GetSkinOrFake(skinForm))
endFunction

; Get a JFormMap with Race keys and JFormMap values with Armor keys and JMap values of creatures registered to a mod
int function GetCreaturesRegisteredToMod(string modId)
	return JMap.GetObj(JMap.GetObj(jModsMap, modId), "creatures")
endFunction

; Test to see if a creature is registered to a mod
bool function IsCreatureRegisteredToMod(string modId, Race raceForm, Armor skinForm)
	Int t = JFormMap.GetObj(jCreaturesMap, raceForm)
	if t
		t = JFormMap.GetObj(t, GetSkinOrFake(skinForm))
		if t
			return JMap.HasKey(JMap.GetObj(t, "mods"), modId)
		endif
	endif
	return false
endFunction

; Get a JArray of all of the races that are registered
int function GetRegisteredRaces()
	return JFormMap.AllKeys(jCreaturesMap)
endFunction

; Get the number of race forms that are registered
int function GetRegisteredRaceCount()
	return JArray.Count(GetRegisteredRaces())
endFunction

; Test to see if a race is registered
bool function IsRaceRegistered(Race raceForm)
	return JFormMap.HasKey(jRacesMap, raceForm)
endFunction

; Get a JArray of all of the races registered to a mod
int function GetRacesRegisteredToMod(string modId)
	return JMap.GetObj(JMap.GetObj(jModsMap, modId), "races")
endFunction

; Get the number of races registered to a mod
int function GetRaceCountRegisteredToMod(string modId)
	return JArray.Count(GetRacesRegisteredToMod(modId))
endFunction

; Test to see if a race is registered to a mod
bool function IsRaceRegisteredToMod(string modId, Race raceForm)
	return JArray.FindForm(JMap.GetObj(JMap.GetObj(jModsMap, modId), "races"), raceForm) != -1
endFunction

; Get a JArray of all of the skins that are registered
int function GetRegisteredSkins()
	return JFormMap.AllKeys(jSkinsMap)
endFunction

; Get the number of skins that are registered
int function GetRegisteredSkinCount()
	return JArray.Count(GetRegisteredSkins())
endFunction

; Test to see if a skin is registered
bool function IsSkinRegistered(Armor skinForm)
	return JFormMap.HasKey(jSkinsMap, GetSkinOrFake(skinForm))
endFunction

; Get a JArray of all of the skins registered to a mod
int function GetSkinsRegisteredToMod(string modId)
	return JMap.GetObj(JMap.GetObj(jModsMap, modId), "skins")
endFunction

; Get the number of skins registered to a mod
int function GetSkinCountRegisteredToMod(string modId)
	return JArray.Count(GetSkinsRegisteredToMod(modId))
endFunction

; Test to see if a skin is registered to a mod
bool function IsSkinRegisteredToMod(string modId, Armor skinForm)
	return JArray.FindForm(JMap.GetObj(JMap.GetObj(jModsMap, modId), "skins"), GetSkinOrFake(skinForm)) != -1
endFunction

; Get a JArray of all of the skins that are registered to a race
int function GetSkinsRegisteredToRace(Race raceForm)
	return JMap.GetObj(JFormMap.GetObj(jRacesMap, raceForm), "skins")
endFunction

; Get the number of skins registered to a race
int function GetSkinCountRegisteredToRace(Race raceForm)
	return JArray.Count(GetSkinsRegisteredToRace(raceForm))
endFunction

; Get a JArray of all of the mod IDs that are registered for a race
int function GetModsRegisteredWithRace(Race raceForm)
	return JMap.GetObj(JFormMap.GetObj(jRacesMap, raceForm), "mods")
endFunction

; Get the number of mods registered for a race
int function GetModCountRegisteredWithRace(Race raceForm)
	return JArray.Count(GetModsRegisteredWithRace(raceForm))
endFunction

; Get a JArray of all of the mod IDs that are registered for a skin
int function GetModsRegisteredWithSkin(Armor skinForm)
	return JMap.GetObj(JFormMap.GetObj(jSkinsMap, GetSkinOrFake(skinForm)), "mods")
endFunction

; Get the number of mods registered for a skin
int function GetModCountRegisteredWithSkin(Armor skinForm)
	return JArray.Count(GetModsRegisteredWithSkin(skinForm))
endFunction

; Get a JArray of all of the mod IDs that are registered for a creature
int function GetModsRegisteredWithCreature(Race raceForm, Armor skinForm)
	return JMap.AllKeys(JMap.GetObj(JFormMap.GetObj(JFormMap.GetObj(jCreaturesMap, raceForm), GetSkinOrFake(skinForm)), "mods"))
endFunction

; Get the number of mods registered for a creature
int function GetModCountRegisteredWithCreature(Race raceForm, Armor skinForm)
	return JArray.Count(GetModsRegisteredWithCreature(raceForm, skinForm))
endFunction

; Get a JMap of a creature registration's properties
int function GetCreatureModMap(string modId, Race raceForm, Armor skinForm)
	return JMap.GetObj(JMap.GetObj(JFormMap.GetObj(JFormMap.GetObj(jCreaturesMap, raceForm), GetSkinOrFake(skinForm)), "mods"), modId)
endFunction

; Get the type of a creature registration
int function GetModCreatureType(string modId, Race raceForm, Armor skinForm)
	return JMap.GetInt(GetCreatureModMap(modId, raceForm, skinForm), "type")
endFunction

; Get the normal armour of a creature registration
Armor function GetModCreatureNormalArmor(string modId, Race raceForm, Armor skinForm)
	return JMap.GetForm(GetCreatureModMap(modId, raceForm, skinForm), "normalArmor") as Armor
endFunction

; Get the aroused armour of a creature registration
Armor function GetModCreatureArousedArmor(string modId, Race raceForm, Armor skinForm)
	return JMap.GetForm(GetCreatureModMap(modId, raceForm, skinForm), "arousedArmor") as Armor
endFunction

; Get whether or not the armour will be stripped for a creature registration
bool function GetModCreatureStripArmor(string modId, Race raceForm, Armor skinForm)
	return JMap.GetInt(GetCreatureModMap(modId, raceForm, skinForm), "stripArmor") as bool
endFunction

; Get whether or not the weapons will be stripped for a creature registration
bool function GetModCreatureStripWeapons(string modId, Race raceForm, Armor skinForm)
	return JMap.GetInt(GetCreatureModMap(modId, raceForm, skinForm), "stripWeapons") as bool
endFunction

; Get the JArray of blacklisted forms for stripping of a creature registration
int function GetModCreatureStripFormBlacklist(string modId, Race raceForm, Armor skinForm)
	return JMap.GetObj(GetCreatureModMap(modId, raceForm, skinForm), "stripFormBlacklist")
endFunction

; Get the JArray of blacklisted slots for stripping of a creature registration
int function GetModCreatureStripSlotBlacklist(string modId, Race raceForm, Armor skinForm)
	return JMap.GetObj(GetCreatureModMap(modId, raceForm, skinForm), "stripSlotBlacklist")
endFunction

; Get the JArray of restricted slots of a creature registration
int function GetModCreatureRestrictedSlots(string modId, Race raceForm, Armor skinForm)
	return JMap.GetObj(GetCreatureModMap(modId, raceForm, skinForm), "restrictedSlots")
endFunction

; Get the name of a race
string function GetRaceName(Race raceForm)
	if raceForm != none
		return JMap.GetStr(JFormMap.GetObj(jRacesMap, raceForm), "name")
	else
		return ""
	endIf
endFunction

; Get the name of a skin
string function GetSkinName(Armor skinForm)
	if skinForm != none && skinForm != FakeSkin
		return JMap.GetStr(JFormMap.GetObj(jSkinsMap, skinForm), "name")
	else
		return ""
	endIf
endFunction


;----------------------------------------------------------------
; JSON registration methods					|
;----------------------------------------------------------------

; Parses any JSON files in the creatures.d directory and registers mods/creatures from them
function LoadJSONRegistrations(bool reload = false)
	if loadingJSON
		CFDebug.Log("[Framework] Not loading JSON registrations; already loading")
		return
	endIf

	muckingAboutPreventor += 1
	loadingJSON = true
	CFDebug.Log("[Framework] Checking JSON registration")
	if config.DbgOutputLog || config.DbgOutputConsole
		Debug.Notification("CF Checking JSON registration")
	endIf
	int jsonFiles = JValue.ReadFromDirectory("Data/creatures.d", ".json")
	if jsonFiles && JMap.Count(jsonFiles)
		JValue.Retain(jsonFiles)
		CFDebug.Log("[Framework] Found " + JMap.Count(jsonFiles) + " JSON files in creatures.d")
		string fileName = JMap.NextKey(jsonFiles)
		while fileName
			if reload || JArray.FindStr(jLoadedFiles, fileName) == -1
				int fileMap = JMap.GetObj(jsonFiles, fileName)
				if fileMap != 0 && JMap.Count(fileMap) > 0
					CFDebug.Log("[Framework] Reading file " + fileName)
					string modID = JMap.GetStr(fileMap, "modID")
					string modName = JMap.GetStr(fileMap, "modName")
					int modCreatures = JMap.GetObj(fileMap, "creatures")
					int modCreatureCount = JArray.Count(modCreatures)
					if modID != "" && modName != "" && modCreatures != 0 && modCreatureCount > 0
						if !IsModRegistered(modID)
							RegisterMod(modID, modName)
						endIf

						int c = 0
						while c < modCreatureCount
							int modCreatureMap = JArray.GetObj(modCreatures, c)
							Race raceForm = JMap.GetForm(modCreatureMap, "raceForm") as Race
							string raceName = JMap.GetStr(modCreatureMap, "raceName")
							if raceForm != none && raceName != ""
								Armor skinForm = JMap.GetForm(modCreatureMap, "skinForm") as Armor
								if !IsCreatureRegisteredToMod(modID, raceForm, skinForm)
									string skinName = JMap.GetStr(modCreatureMap, "skinName")
									Armor normalArmor = JMap.GetForm(modCreatureMap, "normalArmor") as Armor
									Armor arousedArmor = JMap.GetForm(modCreatureMap, "arousedArmor") as Armor
									bool stripArmor = JMap.GetInt(modCreatureMap, "stripArmor") as bool
									bool stripWeapons = !JMap.HasKey(modCreatureMap, "stripWeapons") || JMap.GetInt(modCreatureMap, "stripWeapons")
									Form[] stripFormBlacklist = CreatureFrameworkUtil.FormArrayFromJArray(JMap.GetObj(modCreatureMap, "stripFormBlacklist"))
									int[] stripSlotBlacklist = CreatureFrameworkUtil.IntArrayFromJArray(JMap.GetObj(modCreatureMap, "stripSlotBlacklist"))
									int[] restrictedSlots = CreatureFrameworkUtil.IntArrayFromJArray(JMap.GetObj(modCreatureMap, "restrictedSlots"))
									RegisterCreatureArmorSwapToMod(modID, raceForm, skinForm, raceName, skinName, normalArmor, arousedArmor, stripArmor, stripWeapons, stripFormBlacklist, stripSlotBlacklist, restrictedSlots)
								endIf
							else
								CFDebug.Log("[Framework] File " + filename + " creature " + c + " is missing its race or race name")
								if config.DbgOutputLog || config.DbgOutputConsole
									Debug.Notification("CF File " + filename + " creature " + c + " is missing its race or race name")
								endIf
							endIf
							c += 1
						endWhile

						JArray.AddStr(jLoadedFiles, fileName)
					else
						CFDebug.Log("[Framework] File " + fileName + " is missing a mod ID or name, or has no creatures")
						if config.DbgOutputLog || config.DbgOutputConsole
							Debug.Notification("CF File " + fileName + " is missing a mod ID or name, or has no creatures")
						endIf
					endIf
				else
					CFDebug.Log("[Framework] File " + fileName + " is invalid or empty")
					if config.DbgOutputLog || config.DbgOutputConsole
						Debug.Notification("CF File " + fileName + " is invalid or empty")
					endIf
				endIf
			else
				CFDebug.Log("[Framework] Already loaded file " + fileName + "; skipping")
			endIf

			fileName = JMap.NextKey(jsonFiles, fileName)
		endWhile

		JArray.Unique(jLoadedFiles)
		JValue.Release(jsonFiles)
		JValue.ZeroLifetime(jsonFiles)
	endIf

	CFDebug.Log("[Framework] Finished JSON registration")
	if config.DbgOutputLog || config.DbgOutputConsole
		Debug.Notification("CF Finished JSON registration")
	endIf
	loadingJSON = false
	muckingAboutPreventor -= 1
	if muckingAboutPreventor < 0
		muckingAboutPreventor = 0
	endIf
endFunction

; Get whether or not the JSON registrations are being loaded
bool function IsJSONLoading()
	return loadingJSON
endFunction

; Clears the list of loaded JSON files
function ResetLoadedFiles()
	CFDebug.Log("[Framework] Reset loaded JSON files")
	JArray.Clear(jLoadedFiles)
endFunction


;----------------------------------------------------------------
; Active mod methods						|
;----------------------------------------------------------------

; Select an active mod for a creature, used in function SetActiveModUsingIndex, function ClearActiveForMod and CFConfigMenu script
function SetActiveMod(Race raceForm, Armor skinForm, string modId)
	Armor realSkin
	if skinForm
		realSkin = skinForm
	else
		realSkin = FakeSkin
	endif
	if modId != ""
		if IsCreatureRegisteredToMod(modId, raceForm, realSkin)
			JMap.SetStr(JFormMap.GetObj(JFormMap.GetObj(jCreaturesMap, raceForm), realSkin), "activeMod", modId)
			TriggerUpdate(raceForm, realSkin)
			CFDebug.Log("[Framework] Set the active mod to \"" + modId + "\" for " + CreatureFrameworkUtil.GetDetailedFormName(raceForm) + CreatureFrameworkUtil.GetDetailedFormName(realSkin))
		else
			CFDebug.Log("[Framework] Failed to set the active mod to \"" + modId + "\" for " + CreatureFrameworkUtil.GetDetailedFormName(raceForm) + CreatureFrameworkUtil.GetDetailedFormName(realSkin) + "; creature not registered")
		endIf
	else
		JMap.SetStr(JFormMap.GetObj(JFormMap.GetObj(jCreaturesMap, raceForm), realSkin), "activeMod", modId)
		TriggerUpdate(raceForm, realSkin)
		CFDebug.Log("[Framework] Cleared the active mod for " + CreatureFrameworkUtil.GetDetailedFormName(raceForm) + CreatureFrameworkUtil.GetDetailedFormName(realSkin))
	endIf
endFunction

; Select an active mod for a creature using the mod's relative index rather than the ID, used in CFConfigMenu script
function SetActiveModUsingIndex(Race raceForm, Armor skinForm, int modIndex)
	If modIndex != -1
		SetActiveMod(raceForm, skinForm, JArray.GetStr(GetModsRegisteredWithCreature(raceForm, skinForm), modIndex))
	else
		SetActiveMod(raceForm, skinForm, "")
	endIf
endFunction

; Clear active mod of creatures that had it set to a specific one
function ClearActiveForMod(string modId)
	int races = GetRegisteredRaces()
	int racesSize = JArray.Count(races)
	int r = 0
	while r < racesSize
		Race raceForm = JArray.GetForm(races, r) as Race
		int skins = GetSkinsRegisteredToRace(raceForm)
		int skinsSize = JArray.Count(skins)
		int s = 0
		while s < skinsSize
			Armor skinForm = JArray.GetForm(skins, s) as Armor
			if GetActiveMod(raceForm, skinForm) == modId
				SetActiveMod(raceForm, skinForm, "")
			endIf
			s += 1
		endWhile
		r += 1
	endWhile
endFunction

Int function GetActorMapA(Actor ak)
	ActorBase tAB = ak.GetLeveledActorBase()
	Race raceForm = tAB.GetRace()
	Int t = JFormMap.GetObj(jCreaturesMap, raceForm)
	if t
		Armor skinForm = ak.GetActorBase().GetSkin()
		if !skinForm
			skinForm = tAB.GetSkin()
		endIf
		if !skinForm
			skinForm = ak.GetRace().GetSkin()
		endIf
		if skinForm
			Int tt = JFormMap.GetObj(t, skinForm)
			if tt
				t = tt
			else
				t = JFormMap.GetObj(t, FakeSkin)
			endif
		else
			t = JFormMap.GetObj(t, FakeSkin)
		endif
	endif
	return t
endfunction

; Get the active mod's ID for a creature, used in function ClearActiveForMod.
string function GetActiveMod(Race raceForm, Armor skinForm)
	Int t = JFormMap.GetObj(jCreaturesMap, raceForm)
	if t
		if skinForm
			Int tt = JFormMap.GetObj(t, skinForm)
			if tt
				t = tt
			else
				t = JFormMap.GetObj(t, FakeSkin)
			endif
		else
			t = JFormMap.GetObj(t, FakeSkin)
		endif
		if t
			return JMap.GetStr(t, "activeMod")
		endif
	endif
	return ""
endFunction

; Get the active mod's relative index for a creature, used in CFConfigMenu script
int function GetActiveModIndex(Race raceForm, Armor skinForm)
	return JArray.FindStr(GetModsRegisteredWithCreature(raceForm, skinForm), GetActiveMod(raceForm, skinForm))
endFunction

; Get the active mod's name for a creature, used in CFConfigMenu script
string function GetActiveModName(Race raceForm, Armor skinForm)
	return GetModName(GetActiveMod(raceForm, skinForm))
endFunction

; Trigger an update for a creature, used in function SetActiveMod
function TriggerUpdate(Race raceForm, Armor skinForm)
	if raceForm && skinForm
		Int t = JFormMap.GetObj(jCreaturesMap, raceForm)
		if t
			t = JFormMap.GetObj(t, skinForm)
			if t
				Int i
				while i < 32
					actor akCreature = ACreatures[i]
					if akCreature && ACreaturesMaps[i] == t && akCreature.Is3DLoaded()
						if akCreature.IsDisabled() || (Player.GetDistance(akCreature) > (Config.PrfCloakRange + 1000))
							RemoveArmors(akCreature)
							CFDebug.Log("[Framework] Function TriggerUpdate RemoveArmors" + akCreature)
							if AFlags[i] >= 1
								EquipA(akCreature, true, true)
							endif
							ACreatures[i] = none
						else
;EDIT----------------------------------------------------------------------------------------
;							if SexLab.IsActorActive(akCreature)
							if OActor.IsInOstim(akCreature) || Config.GenAroused && akCreature.GetFactionRank(ArousedFaction) >= Config.GenArousalThreshold
;EDIT----------------------------------------------------------------------------------------
							ChangeArousal(i, 1, true)
								CFDebug.Log("[Framework] Function TriggerUpdate ChangeArousal (is Aroused)" + akCreature)
							else
								ChangeArousal(i, 0, true)
								CFDebug.Log("[Framework] Function TriggerUpdate ChangeArousal (not Aroused)" + akCreature)
							endif
						endif
					endif
					i += 1
				endwhile
			endif
		endif
	endif
endFunction

; Trigger an update for an actor, used in CFConfigMenu script
function TriggerUpdateForActor(Actor actorForm)
	if actorForm && actorForm.Is3DLoaded()
		Int i = ACreatures.Find(actorForm)
		if i == -1 || actorForm.IsDisabled() || (Player.GetDistance(actorForm) > (Config.PrfCloakRange + 500))
			RemoveArmors(actorForm)
			CFDebug.Log("[Framework] Function TriggerUpdateForActor RemoveArmors" + actorForm)
			if i >= 0
				if AFlags[i] >= 1
					EquipA(actorForm, true, true)
				endif
				ACreatures[i] = none
			endif
		else
;EDIT----------------------------------------------------------------------------------------
;			if SexLab.IsActorActive(actorForm)
			if OActor.IsInOstim(actorForm) || Config.GenAroused && actorForm.GetFactionRank(ArousedFaction) >= Config.GenArousalThreshold
;EDIT----------------------------------------------------------------------------------------
			ChangeArousal(i, 1, true)
				CFDebug.Log("[Framework] Function TriggerUpdateForActor ChangeArousal (is Aroused)" + actorForm)
			else
				ChangeArousal(i, 0, true)
				CFDebug.Log("[Framework] Function TriggerUpdateForActor ChangeArousal (not Aroused)" + actorForm)
			endif
		endif
	endif
endFunction

;----------------------------------------------------------------
; Arousal methods						|
;----------------------------------------------------------------

; Test to see if a creature is aroused, used in event OnModifyExposure.
bool function IsAroused(Actor actorForm, bool havingSex = false)
;EDIT----------------------------------------------------------------------------------------
;	If havingSex || (Config.GenSexLab && SexLab && SexLab.IsActorActive(actorForm))
	If havingSex || (Config.GenOstim && OActor.IsInOstim(actorForm))
;EDIT----------------------------------------------------------------------------------------
		return true
	elseIf Config.GenAroused && actorForm.GetFactionRank(ArousedFaction) >= Config.GenArousalThreshold
		return true
	else
		return false
	endIf
endFunction

; Get the source of arousal for a creature, used in CFConfigMenu script.
int function GetArousalSource(Actor actorForm, bool havingSex = false)
	If havingSex || IsOnSexScene(actorForm)
		return 1
	elseIf Config.GenAroused && actorForm.GetFactionRank(ArousedFaction) >= Config.GenArousalThreshold
		return 2
	else
		return 0
	endIf
endFunction

; Get the textual form of an arousal source, used in CFConfigMenu script.
string function GetArousalSourceText(int arousalSource)
	if arousalSource > -1 && arousalSource < arousalSources.length
		return arousalSources[arousalSource]
	else
		return "$None"
	endIf
endFunction

; used in CFConfigMenu script for Cloak cooldown setting
Function TimeSettingChanged()
	UnregisterForUpdate()
	RegisterForSingleUpdate(Config.PrfTimeout)
endFunction

; used in CFConfigMenu script for Arousal threshold setting
Function ArousedSettingChanged()
	int i
	while i < 32
		actor akCreature = ACreatures[i]
		if akCreature
			if akCreature.Is3DLoaded()
				if AFlags[i] < 1
					ChangeArousal(i, 0, true) ;default false
					CFDebug.Log("[Framework] Function ArousedSettingChanged ChangeArousal" +akCreature)
					Utility.Wait(0.1)
				endif
			else
				ACreatures[i] = none
			endif
		endif
		i += 1
	endwhile
Endfunction

;----------------------------------------------------------------
; Event methods							|
;----------------------------------------------------------------

; Fire an arousal event, used in function ChangeArousal.
string function FireEvent(string modId, Actor actorForm, bool aroused, Race raceForm = none, Armor skinForm = none, bool fromSex = true, bool fromArousal = false, bool fromUnequip = false, int arousalRating = -1, Armor unequippedArmor = none)
	; Create the event
	int eventHandle = ModEvent.Create("CFArousalChange_" + modId)
	if eventHandle
		ModEvent.PushForm(eventHandle, self)

		; Make a unique event ID
		string eventId = modId + "_" + actorForm.GetFormID() + "_" + Utility.RandomInt(-100000, 100000)
		ModEvent.PushString(eventHandle, eventId)

		; Grab the race and skin if they haven't been provided
		if raceForm == none
			raceForm = actorForm.GetLeveledActorBase().GetRace()
		endIf
		if skinForm == none
			skinForm = GetSkinOrFakeFromActor(actorForm)
			if !IsCreatureRegisteredToMod(modId, raceForm, skinForm) && skinForm != FakeSkin
				skinForm = FakeSkin
			endIf
		endIf

		; Get the arousal rating of the actor if it isn't provided
		if arousalRating == -1 && SexLabAroused && Config.GenAroused
			arousalRating = actorForm.GetFactionRank(ArousedFaction)
		endIf

		; Make the map for the event and add it
		int eventMap = JMap.Object()
		JMap.SetStr(eventMap, "id", eventId)
		JMap.SetForm(eventMap, "actor", actorForm)
		JMap.SetInt(eventMap, "aroused", aroused as int)
		JMap.SetForm(eventMap, "race", raceForm)
		JMap.SetForm(eventMap, "skin", skinForm)
		JMap.SetInt(eventMap, "arousal", arousalRating)
		JMap.SetForm(eventMap, "unequippedArmor", unequippedArmor)
		JMap.SetInt(eventMap, "fromSex", fromSex as int)
		JMap.SetInt(eventMap, "fromArousal", fromArousal as int)
		JMap.SetInt(eventMap, "fromUnequip", fromUnequip as int)
		JMap.SetObj(jEventsMap, eventId, eventMap)

		; Fire away
		CFDebug.Log("[Framework] Firing event \"" + eventId + "\" for " + actorForm)
		ModEvent.Send(eventHandle)
		return eventId
	else
		CFDebug.Log("[Framework] Unable to fire event for " + actorForm + "; invalid handle")
	endIf

	return none
endFunction


; MadMansGun: no clue what any of the following is used for.
;==================================================================

; Dispose of an event
function FinishEvent(string eventId)
	JMap.RemoveKey(jEventsMap, eventId)
endFunction

; Get the event data JMap
int function GetEventData(string eventId)
	return JMap.GetObj(jEventsMap, eventId)
endFunction

; Get the actor that an event is triggered for
Actor function GetEventActor(string eventId)
	return JMap.GetForm(JMap.GetObj(jEventsMap, eventId), "actor") as Actor
endFunction

; Get whether or not the actor the event is triggered for is aroused
bool function IsEventAroused(string eventId)
	return JMap.GetInt(JMap.GetObj(jEventsMap, eventId), "aroused") as bool
endFunction

; Get the race of the actor the event is triggered for
Race function GetEventRace(string eventId)
	return JMap.GetForm(JMap.GetObj(jEventsMap, eventId), "race") as Race
endFunction

; Get the skin of the actor the event is triggered for
Armor function GetEventSkin(string eventId)
	return JMap.GetForm(JMap.GetObj(jEventsMap, eventId), "skin") as Armor
endFunction

; Get the arousal rating of the actor the event is triggered for
int function GetEventArousal(string eventId)
	return JMap.GetInt(JMap.GetObj(jEventsMap, eventId), "arousal")
endFunction

; Get the unequipped armour that triggered the event
Armor function GetEventUnequippedArmor(string eventId)
	return JMap.GetForm(JMap.GetObj(jEventsMap, eventId), "unequippedArmor") as Armor
endFunction

; Get whether or not the event was triggered from sex
bool function IsEventFromSex(string eventId)
	return JMap.GetInt(JMap.GetObj(jEventsMap, eventId), "fromSex") as bool
endFunction

; Get whether or not the event was triggered from arousal
bool function IsEventFromArousal(string eventId)
	return JMap.GetInt(JMap.GetObj(jEventsMap, eventId), "fromArousal") as bool
endFunction

; Get whether or not the event was triggered from an unequip event
bool function IsEventFromUnequip(string eventId)
	return JMap.GetInt(JMap.GetObj(jEventsMap, eventId), "fromUnequip") as bool
endFunction

; Clear the events
function ClearEvents()
	JMap.Clear(jEventsMap)
endFunction

;==================================================================


;----------------------------------------------------------------
; Active actor methods						|
;----------------------------------------------------------------

; Add an active actor, used in event OnSexLabAnimationStart, event OnModifyExposure and event OnUpdate.
bool function ActivateActor(Actor actorForm)
	return ActivateActorA(actorForm, false)
endfunction
;EDIT----------------------------------------------------------------------------------------
;bool function ActivateActorA(Actor actorForm, bool IsSexLabActive)
bool function ActivateActorA(Actor actorForm, bool IsOstimActive)
	if !restartingActiveActors
		int f
		;if IsSexLabActive
		if IsOstimActive
			f = 1
;EDIT----------------------------------------------------------------------------------------
		endif
		int i = ACreatures.Find(actorForm)
		if i == -1
			i = ACreatures.Find(none)
			if i >= 0
				Int ActorMapz = GetActorMapA(actorForm)
				if ActorMapz && JMap.GetStr(ActorMapz, "activeMod")
					ACreatures[i] = actorForm
					ACreaturesMaps[i] = ActorMapz
					ChangeArousal(i, f, false) ;default false
					CFDebug.Log("[Framework] function ActivateActorA ActorMapz ChangeArousal" + actorForm)
					return true
				endif
			endif
;EDIT----------------------------------------------------------------------------------------			
		;elseif  SexLab.IsActorActive(actorForm) || Config.GenAroused && actorForm.GetFactionRank(ArousedFaction) >= Config.GenArousalThreshold
		elseif  OActor.IsInOstim(actorForm) || Config.GenAroused && actorForm.GetFactionRank(ArousedFaction) >= Config.GenArousalThreshold
;EDIT----------------------------------------------------------------------------------------		
			if actorForm.WornHasKeyword(ArmorArousedKeyword)
				ChangeArousal(i, 1, false) ;default false
				CFDebug.Log("[Framework] function ActivateActorA ChangeArousal (is Aroused)" + actorForm)
				return true
			else
				ChangeArousal(i, 1, true) ;default true
				CFDebug.Log("[Framework] function ActivateActorA ChangeArousal (should be Aroused but is not)" + actorForm)
				return true
			endif
		else
			if  actorForm.WornHasKeyword(ArmorNormalKeyword)
				ChangeArousal(i, 0, false) ;default false
				CFDebug.Log("[Framework] function ActivateActorA ChangeArousal (not Aroused)" + actorForm)
				return true
			else
				ChangeArousal(i, 0, true) ;default false
				CFDebug.Log("[Framework] function ActivateActorA ChangeArousal (should not be Aroused)" + actorForm)
				return true
			endif
		endIf
	endIf
	return false
endFunction

; Remove an active actor.
; MadMansGun: not sure if actually used, i can't find any calls.
bool function DeactivateActor(Actor actorForm)
	if !restartingActiveActors
		int i = ACreatures.Find(actorForm)
		if i == -1
			return false
		else
			RemoveArmors(actorForm)
			CFDebug.Log("[Framework] Function DeactivateActor RemoveArmors" + actorForm)
			if AFlags[i] >= 1
				EquipA(actorForm, true, true)
			endif
			ACreatures[i] = none
			return true
		endIf
	else
		return false
	endIf
endFunction

; Test to see if an actor is active.
; MadMansGun: not sure if actually used or not, i can only find "SexLab.IsActorActive" being used.
bool function IsActorActive(Actor actorForm)
	if !actorForm || actorForm == none
		return false
	endIf
	return ACreatures.Find(actorForm) != -1
endFunction

;used in function GetArousalSource, function ChangeArousal.
bool function IsOnSexScene(Actor actorForm)
	if !actorForm || actorForm == none
		return false
	endIf
;EDIT----------------------------------------------------------------------------------------
	;return Config.GenSexLab && SexLab && SexLab.IsActorActive(actorForm)
	return Config.GenOstim && OActor.IsInOstim(actorForm)
;EDIT----------------------------------------------------------------------------------------
endFunction

; Remove the active actors that are no longer valid
function ClearInvalidActiveActors()
	RestartActiveActors()
endFunction

; Force all active actors' creature spells to be removed and re-added, used in function Initialize.
function RestartActiveActors()
	if restartingActiveActors
		return
	endIf
	restartingActiveActors = true
	Int i = 0
	while i < 32
		actor akCreature = ACreatures[i]
		if akCreature && akCreature != none
			if !akCreature.Is3DLoaded()
				ACreatures[i] = none
			elseif akCreature.IsDisabled() || (Player.GetDistance(akCreature) > (Config.PrfCloakRange + 500))
				RemoveArmors(akCreature)
				CFDebug.Log("[Framework] Function RestartActiveActors RemoveArmors" + akCreature)
				if AFlags[i] >= 1
					AFlags[i] = 1
					EquipA(akCreature, true, true)
				endif
				ACreatures[i] = none
			elseif AFlags[i] <= 0
				AFlags[i] = 0
				ChangeArousal(i, 0, true) ;default true
				CFDebug.Log("[Framework] Function RestartActiveActors ChangeArousal" + akCreature)
			endif
		endif
		i += 1
	endWhile
	restartingActiveActors = false
endFunction

; Get whether or not the active actors are being restarted
bool function AreActiveActorsRestarting()
	return restartingActiveActors
endFunction


;----------------------------------------------------------------
; SexLab animation events					|
;----------------------------------------------------------------
;EDIT----------------------------------------------------------------------------------------
;event OnSexLabAnimationStart(string EventName, string argString, Float argNum, form sender)
;	if SexLab && Config.GenSexLab
;		Actor[] actors = SexLab.GetController(argString as int).Positions
event OnOstimAnimationStart(string EventName, string argString, Float argNum, form sender)
	if Config.GenOstim
		Actor[] actors = OThread.GetActors(argNum as int)
;EDIT----------------------------------------------------------------------------------------
		int a
		while a < actors.length
			if IsCreature(actors[a])
				Int i = ACreatures.Find(actors[a])
				if i >= 0 
					if actors[a].WornHasKeyword(ArmorArousedKeyword)
						ChangeArousal(i, 1, false)
					else
						ChangeArousal(i, 1, true)
					endif
				endif
				Cell ParentCell = actors[a].GetParentCell()
				if ParentCell && ParentCell.IsAttached() && ActivateActorA(actors[a], true)
					Debug.SendAnimationEvent(actors[a], "SOSFastErect")
				endIf
			endif
			a += 1
		endWhile
	endIf
endEvent
;EDIT----------------------------------------------------------------------------------------
;event OnSexLabAnimationEnd(string EventName, string argString, Float argNum, form sender)
;	if (SexLab && Config.GenSexLab)
;		Actor[] actors = SexLab.GetController(argString as int).Positions
event OnOstimAnimationEnd(string EventName, string argString, Float argNum, form sender)
	if Config.GenOstim
		Actor[] actors = OJSON.GetActors(argString as int)
;EDIT----------------------------------------------------------------------------------------
		Utility.Wait(0.1)
		int a
		while a < actors.length
			if IsCreature(actors[a])
				int i = ACreatures.Find(actors[a])
				if i >= 0
					if Config.GenAroused && actors[a].GetFactionRank(ArousedFaction) >= Config.GenArousalThreshold
						ChangeArousal(i, 1, false)
						CFDebug.Log("[Framework] event OnSexLabAnimationEnd ChangeArousal (Stay Aroused)" + actors[a])
					else
						ChangeArousal(i, 0, true)
						CFDebug.Log("[Framework] event OnSexLabAnimationEnd ChangeArousal (not Aroused)" + actors[a])
					endif
				endIf
			endif
			a += 1
		endWhile
	endIf
endEvent

event OnModifyExposure(Form actorForm, Float exposureValue)

	actor akCreature = actorForm As Actor
		if akCreature && akCreature != none && !IsCreature(akCreature)	
			int i = ACreatures.Find(akCreature)
			if i >= 0
				if akCreature.Is3DLoaded()
					if (Player.GetDistance(akCreature) > (Config.PrfCloakRange + 500))
						RemoveArmors(akCreature)
						CFDebug.Log("[Framework] Event OnModifyExposure RemoveArmors" + akCreature)
						if AFlags[i] >= 1
							EquipA(akCreature, true, true)
						endif
						ACreatures[i] = none
;EDIT----------------------------------------------------------------------------------------
;					elseif  SexLab.IsActorActive(akCreature) || Config.GenAroused && akCreature.GetFactionRank(ArousedFaction) >= Config.GenArousalThreshold
					elseif  OActor.IsInOstim(akCreature) || Config.GenAroused && akCreature.GetFactionRank(ArousedFaction) >= Config.GenArousalThreshold
;EDIT----------------------------------------------------------------------------------------
						if akCreature.WornHasKeyword(ArmorArousedKeyword)
							ChangeArousal(i, 1, false) ;default false
							CFDebug.Log("[Framework] Event OnModifyExposure ChangeArousal (is Aroused)" + akCreature)
						else
							ChangeArousal(i, 1, true) ;default true
							CFDebug.Log("[Framework] Event OnModifyExposure ChangeArousal (should be Aroused but is not)" + akCreature)
						endif
					else
						if  akCreature.WornHasKeyword(ArmorNormalKeyword)
							ChangeArousal(i, 0, false) ;default false
							CFDebug.Log("[Framework] Event OnModifyExposure ChangeArousal (not Aroused)" + akCreature)
						else
							ChangeArousal(i, 0, true) ;default false
							CFDebug.Log("[Framework] Event OnModifyExposure ChangeArousal (should not be Aroused)" + akCreature)
						endif
					endIf
				else
					ACreatures[i] = none
				endif
				Utility.Wait(0.1)
			elseif IsAroused(akCreature) && (Player.GetDistance(akCreature) < Config.PrfCloakRange)
				ActivateActor(akCreature)
				CFDebug.Log("[Framework] event OnModifyExposure ActivateActor" + akCreature)
				Utility.Wait(0.1)
			endif
		endif
    
endEvent

;----------------------------------------------------------------
; Puppet methods						|
;----------------------------------------------------------------

; Set the puppet
function SetPuppet(Actor actorForm)
	puppet = actorForm
	CFDebug.Log("[Framework] function Setpuppet " + CreatureFrameworkUtil.GetDetailedActorName(puppet))
endFunction

; Get the puppet
Actor function GetPuppet()
	return puppet
endFunction

;----------------------------------------------------------------
; Form DB methods						|
;----------------------------------------------------------------

 ; Clear the entire Form DB
 function ClearFormDB()
 	JDB.SetObj("CFForm", 0)
 endFunction

; Clear the log Form DB
function ClearLogFormDB()
	JDB.SetObj("CFFormLog", 0)
endFunction

; Reset the Form DB clear timer
function ResetFormDBClearTimer()
endFunction

;----------------------------------------------------------------
; Utility methods						|
;----------------------------------------------------------------

; Get the version of the mod
int function GetVersion()
	return CreatureFrameworkUtil.GetVersion()
endFunction

; Get the textual representation of the version of the mod
string function GetVersionString()
	return CreatureFrameworkUtil.GetVersionString()
endFunction
;EDIT----------------------------------------------------------------------------------------
; Test to see if SexLab is installed
;bool function IsSexLabInstalled()
;	return SexLab != none
;endFunction

; Test to see if SexLab is enabled
;bool function IsSexLabEnabled()
;	return SexLab && Config.GenSexLab
;endFunction
;EDIT----------------------------------------------------------------------------------------
; Test to see if SexLab Aroused is installed
bool function IsArousedInstalled()
	return SexLabAroused != none
endFunction

; Test to see if SexLab Aroused is enabled
bool function IsArousedEnabled()
	return SexLabAroused && Config.GenAroused
endFunction

; Test to see if an actor is on valid stage to be updated, used in event OnUpdate.
bool function IsValidForUpdate(Actor actorForm)
	if !actorForm || actorForm == none
		return false
	endIf
	return !(actorForm.GetFlyingState() > 0 || actorForm.GetCurrentScene() != none || actorForm.IsInKillMove())
	CFDebug.Log("[Framework] function IsValidForUpdate" + actorForm)
endFunction

; Test to see if an actor is a creature, used in almost everything.
bool function IsCreature(Actor actorForm)
	if !actorForm || actorForm == none
		return false
	endIf
	Race akRace = actorForm.GetLeveledActorBase().GetRace()
	if akRace && akRace != none
		return IsCreatureRace(akRace)
	endIf
	return false
endFunction

; Test to see if a race is a creature race, no human scum allowed.
bool function IsCreatureRace(Race raceForm)
	if !raceForm || raceForm == none
		return false
	endIf
	return (raceForm.HasKeyword(CreatureKeyword) || raceForm.HasKeyword(AnimalKeyword) || raceForm.HasKeyword(DwarvenKeyword))
endFunction

; Get the fake skin if the skin passed is none, or the skin itself if not
Armor function GetSkinOrFake(Armor skinForm)
	if skinForm && skinForm != none
		return skinForm
	else
		return FakeSkin
	endIf
endFunction

; Get the real skin from an Actor
Armor function GetSkinOrFakeFromActor(Actor actorForm)
	if actorForm || actorForm != none
		Armor skinForm = actorForm.GetActorBase().GetSkin()
		if skinForm
			return skinForm
		endIf
		skinForm = actorForm.GetLeveledActorBase().GetSkin()
		if skinForm
			return skinForm
		endIf
		skinForm = actorForm.GetRace().GetSkin()
		if skinForm
			return skinForm
		endIf
	endIf
	return FakeSkin
endFunction

; Remove the unaroused and aroused armours from an actor, used in almost everything.
function RemoveArmors(Actor actorForm, bool removeNormal = true, bool removeAroused = true)
	if !actorForm || actorForm == none
		return
	endIf
	int i
	while i < actorForm.GetNumItems()
		Form item = actorForm.GetNthForm(i)
;EDIT----------------------------------------------------------------------------------------		
;		if (removeNormal && item.HasKeyword(ArmorNormalKeyword)) || (removeAroused && item.HasKeyword(ArmorArousedKeyword) && !SexLab.IsActorActive(actorForm))
if (removeNormal && item.HasKeyword(ArmorNormalKeyword)) || (removeAroused && item.HasKeyword(ArmorArousedKeyword) && !OActor.IsInOstim(actorForm))
;EDIT----------------------------------------------------------------------------------------		
		actorForm.UnequipItem(item, false, true)
			actorForm.RemoveItem(item, 5, true)
			CFDebug.Log("[Framework] Function RemoveArmors" + actorForm)
		else
			i += 1
		endIf
	endWhile
endFunction

; Get the array of armour slots
int[] function GetArmorSlots()
	return armorSlots
endFunction

; Dump the framework data to "CreatureFramework.json"
function Dump()
	JValue.WriteToFile(jMainMap, "CreatureFramework.json")
	CFDebug.Log("[Framework] Dumped framework data to Skyrim directory")
endFunction

;----------------------------------------------------------------
; mucking about prevention					|
;----------------------------------------------------------------

; Prevent mucking about with stuff while stuff is happening
function PreventMuckingAbout()
	muckingAboutPreventor += 1
endFunction

; Reallow mucking about
function AllowMuckingAbout()
	muckingAboutPreventor -= 1
	if muckingAboutPreventor < 0
		muckingAboutPreventor = 0
	endIf
endFunction

; Reset all mucking about prevention
function ResetMuckingAboutPrevention()
	muckingAboutPreventor = 0
endFunction

; Get whether or not we're allowed to muck about
bool function IsMuckingAboutAllowed()
	return muckingAboutPreventor == 0
endFunction

;----------------------------------------------------------------
; Arousal State and Armor Stripping				|
;----------------------------------------------------------------

quest UnboundQ
; The OnUpdate event
event OnUpdate()
	if AltStartMod == 0 && !UnboundQ.GetStageDone(250)
		CFDebug.Log("[Framework] 'Unbound' Quest early stage detected - skipping event OnUpdate to prevet issues")
		RegisterForSingleUpdate(360)
	else
		int i
		while i < 32
			actor akCreature = ACreatures[i]
			if akCreature && akCreature != none && IsValidForUpdate(akCreature) ; Mostly checking for flying to avoid Dragon issues.
				;CFDebug.Log("[Framework] Event OnUpdate Updating:["+i+"]"+ akCreature)
				CFDebug.Log("[Framework] Event OnUpdate Updating:"+ akCreature)
				if akCreature.Is3DLoaded()
					if (Player.GetDistance(akCreature) > (Config.PrfCloakRange + 1000)) || !IsCreature(akCreature)
						RemoveArmors(akCreature)
						CFDebug.Log("[Framework] Event OnUpdate RemoveArmors" + akCreature)
						if AFlags[i] >= 1
							EquipA(akCreature, true, true)
						endif
						ACreatures[i] = none
;EDIT----------------------------------------------------------------------------------------
;					elseif  SexLab.IsActorActive(akCreature) || Config.GenAroused && akCreature.GetFactionRank(ArousedFaction) >= Config.GenArousalThreshold
					elseif  OActor.IsInOstim(akCreature) || Config.GenAroused && akCreature.GetFactionRank(ArousedFaction) >= Config.GenArousalThreshold
;EDIT----------------------------------------------------------------------------------------
						if akCreature.WornHasKeyword(ArmorArousedKeyword)
							ChangeArousal(i, 1, false) ;default false
							CFDebug.Log("[Framework] Event OnUpdate ChangeArousal (is Aroused)" + akCreature)
						else
							ChangeArousal(i, 1, true) ;default true
							CFDebug.Log("[Framework] Event OnUpdate ChangeArousal (should be Aroused but is not)" + akCreature)
						endif
					else
						if  akCreature.WornHasKeyword(ArmorNormalKeyword)
							ChangeArousal(i, 0, false) ;default false
							CFDebug.Log("[Framework] Event OnUpdate ChangeArousal (not Aroused)" + akCreature)
						else
							ChangeArousal(i, 0, true) ;default false
							CFDebug.Log("[Framework] Event OnUpdate ChangeArousal (should not be Aroused)" + akCreature)
						endif
					endIf
				elseIf ACreatures[i] != none
					CFDebug.Log("[Framework] event OnUpdate Removing Unloaded Actor")
					ACreatures[i] = none
				endif
				Utility.Wait(0.1)
			endif
			i += 1
		endwhile
		Detect.Start()
		Utility.Wait(0.1)
		if !Detect.IsRunning()
			CFDebug.Log("[Framework] ScanQuest(Detect) can't Start OnUpdate")
			RegisterForSingleUpdate(120)
		else
			i = 0
			int AliasCount = Detect.GetNumAliases()
			if AliasCount > Config.PrfCloakCreatures
				AliasCount = Config.PrfCloakCreatures
			endIf
			while i < AliasCount
				Actor ta = (Detect.GetNthAlias(i) As ReferenceAlias).GetActorReference()
				CFDebug.Log("[Framework] event OnUpdate Detecting:["+i+"]"+ ta)
				if ta && IsValidForUpdate(ta) && (Player.GetDistance(ta) < Config.PrfCloakRange) ; Check Flying to avoid Dragon issues.
					ActivateActor(ta)
					CFDebug.Log("[Framework] event OnUpdate ActivateActor:"+ ta)
					Utility.Wait(0.1)
				endif
				i += 1
			endwhile
			Detect.Stop()
			RegisterForSingleUpdate(Config.PrfTimeout)
		endif
	endIf

endEvent

function ClearCreatures()
	Int i
	while i < 32
		actor akCreature = ACreatures[i]
		if akCreature
			RemoveArmors(akCreature)
			CFDebug.Log("[Framework] Function ClearCreatures RemoveArmors" + akCreature)
			if AFlags[i] >= 1
				EquipA(akCreature, true, true)
			endif
			ACreatures[i] = none
		endif
		i += 1
	endwhile
Endfunction

; Change the actor's arousal state, used in almost everything.
; SexLabState: 0=not active, 1=playing animation.
; Flags: 0=Creature not aroused, 1=Creature is aroused.
;EDIT----------------------------------------------------------------------------------------
;function ChangeArousal(Int CreatureI, Int SexLabState, Bool ForceChange)
function ChangeArousal(Int CreatureI, Int OstimState, Bool ForceChange)
;EDIT----------------------------------------------------------------------------------------
	if CreatureI < 0
		return
	endif
	if !ACreatures[CreatureI] || ACreatures[CreatureI] == none
		return
	endif
	Actor thisCreature = ACreatures[CreatureI] 
	if rcGuard
		Utility.wait(0.15)
		if rcGuard
			Utility.wait(0.15)
			if rcGuard
				return
			endif
		endif
	endif
	rcGuard = true
	Int NewFlag
	Int OldFlag = AFlags[CreatureI]
	; MadMansGun: script edited to be less convoluted, hopefully i got this right.
;EDIT----------------------------------------------------------------------------------------
;	if SexLabState == 1 					;SexLab is running.
	if OstimState == 1
		NewFlag = 1 					;Creature is having sex.
	elseif Config.GenAroused && thisCreature.GetFactionRank(ArousedFaction) >= Config.GenArousalThreshold
;		SexLabState = 0					;SexLab not running.
		OstimState = 0
		NewFlag = 1 					;Creature is aroused but not having sex.
	else
;		SexLabState = 0 				;SexLab not running.
		OstimState = 0
		NewFlag = 0 					;Creature not aroused.
	endIf
;EDIT----------------------------------------------------------------------------------------
	if (ForceChange || OldFlag != NewFlag)
		string activeMod = JMap.GetStr(ACreaturesMaps[CreatureI], "activeMod")
		if activeMod
			int creatureModMap = JMap.GetObj(JMap.GetObj(ACreaturesMaps[CreatureI], "mods"), activeMod)
			int creatureModType = JMap.GetInt(creatureModMap, "type")
			int jRestrictedSlots = JMap.GetObj(creatureModMap, "restrictedSlots")
			bool stripArmor = JMap.GetInt(creatureModMap, "stripArmor") as bool
			bool stripWeapons = JMap.GetInt(creatureModMap, "stripWeapons") as bool
			; Ensure the restricted slots are empty if necessary
;EDIT----------------------------------------------------------------------------------------			
;			if !(SexLabState && stripArmor) && CreatureFrameworkUtil.ActorHasAnyEquippedSlot(thisCreature, jRestrictedSlots)
			if !(OstimState && stripArmor) && CreatureFrameworkUtil.ActorHasAnyEquippedSlot(thisCreature, jRestrictedSlots)
;EDIT----------------------------------------------------------------------------------------			
			AFlags[CreatureI] = NewFlag
				rcGuard = false
				return
			endIf
			; Strip/restore armour if we came from sex
;EDIT----------------------------------------------------------------------------------------			
;			if SexLabState
			if OstimState			
			if IsCreature(thisCreature)
;					if SexLabState == 1 && NewFlag == 1
					if OstimState == 1 && NewFlag == 1
						StripA(thisCreature, creatureModMap, stripArmor, stripWeapons)
					else
						EquipA(thisCreature, stripArmor, stripWeapons)
					endif
				else
;					SexLabState = 0
					OstimState
				endif
			endif
;EDIT----------------------------------------------------------------------------------------			
			; Handle the armour swap
			if creatureModType == 1
				if true  ;MadMansGun: BadDog changed it to "true" from "ForceChange || !OldFlag || !NewFlag" but i'm unsure about this.
					Armor normalArmor
					Armor arousedArmor
					if creatureModType == 1
						normalArmor = JMap.GetForm(creatureModMap, "normalArmor") as Armor
						arousedArmor = JMap.GetForm(creatureModMap, "arousedArmor") as Armor
					endIf
					if !arousedArmor
						arousedArmor = normalArmor
					endif
					if normalArmor != arousedArmor || (ForceChange && arousedArmor)
						RemoveArmors(thisCreature)
						CFDebug.Log("[Framework] Function ChangeArousal ForceChange RemoveArmors" + thisCreature)
						;Utility.Wait(0.05)
						if NewFlag
							CreatureFrameworkUtil.AddAndEquipArmor(thisCreature, arousedArmor)
						else
							if normalArmor
								CreatureFrameworkUtil.AddAndEquipArmor(thisCreature, normalArmor)
							endIf
						endif
					endif
				endif
			endif
			; Handle the event
			if creatureModType == 0 || creatureModType == 2
;EDIT----------------------------------------------------------------------------------------			
;				FireEvent(activeMod, thisCreature, NewFlag as Bool, none, none, SexLabState as Bool, !SexLabState, false)
				FireEvent(activeMod, thisCreature, NewFlag as Bool, none, none, OstimState as Bool, !OstimState, false)
			endIf
			; Strip the weapons and armour extra hard
;			if SexLabState == 1
			if OstimState == 1
;EDIT----------------------------------------------------------------------------------------			
			UnequipSomeMore(thisCreature, stripArmor, stripWeapons)
			endif
		else
			RemoveArmors(thisCreature)
			CFDebug.Log("[Framework] Function ChangeArousal RemoveArmors" + thisCreature)
			if OldFlag == 1
				EquipA(thisCreature, true, true)
			endif
			thisCreature = none
		endif
		
		AFlags[CreatureI] = NewFlag
	endif
	rcGuard = false
Endfunction
function EquipA(Actor target, Bool stripArmor, Bool stripWeapons)
	if !target || target == none
		return
	endIf
	; Cover them back up
	if stripArmor
		int s = 0
		while s < armorSlots.length
			Armor wornArmor = JFormDB.GetForm(target, ".CFForm.StrippedArmor" + s) as Armor
			if wornArmor
				target.EquipItem(wornArmor, false, true)
				JFormDB.SetForm(target, ".CFForm.StrippedArmor" + s, none)
				Utility.Wait(0.05)
			endIf
			s += 1
		endWhile
	endIf

	; Make them lethal again
	if stripWeapons
		Form aHand = JFormDB.GetForm(target, ".CFForm.StrippedWeaponLeft")
		if aHand
			CreatureFrameworkUtil.GenericEquip(target, aHand, false, 0)
			JFormDB.SetForm(target, ".CFForm.StrippedWeaponLeft", none)
			Utility.Wait(0.05)
		endIf
		aHand = JFormDB.GetForm(target, ".CFForm.StrippedWeaponRight")
		if aHand
			CreatureFrameworkUtil.GenericEquip(target, aHand, false, 1)
			JFormDB.SetForm(target, ".CFForm.StrippedWeaponRight", none)
		endIf
	endIf
	Utility.Wait(0.05)
Endfunction
function StripA(Actor target, Int creatureModMap, Bool stripArmor, Bool stripWeapons)
	if !target || target == none
		return
	endIf
	int jFormBlacklist = JMap.GetObj(creatureModMap, "stripFormBlacklist")
	; Strip away that armour
	if stripArmor
		int jSlotBlacklist = JMap.GetObj(creatureModMap, "stripSlotBlacklist")
		int s = 0
		while s < armorSlots.length
			Armor wornArmor = target.GetWornForm(armorSlots[s]) as Armor
			if wornArmor
				if !wornArmor.HasKeyword(ArmorNormalKeyword) && !wornArmor.HasKeyword(ArmorArousedKeyword)
					if JArray.FindForm(jFormBlacklist, wornArmor) == -1 && JArray.FindInt(jSlotBlacklist, armorSlots[s]) == -1
						target.UnequipItem(wornArmor, true, true)
						JFormDB.SetForm(target, ".CFForm.StrippedArmor" + s, wornArmor)
						Utility.Wait(0.05)
					endIf
				endIf
			endIf
			s += 1
		endWhile
	endIf

	; Take away their pointy sticks
	if stripWeapons
		Form aHand = target.GetEquippedObject(0)
		if aHand
			JFormDB.SetForm(target, ".CFForm.StrippedWeaponLeft", aHand)
			CreatureFrameworkUtil.GenericUnequip(target, aHand, true, 0)
			Utility.Wait(0.05)
		endIf
		aHand = target.GetEquippedObject(1)
		if aHand
			JFormDB.SetForm(target, ".CFForm.StrippedWeaponRight", aHand)
			CreatureFrameworkUtil.GenericUnequip(target, aHand, true, 1)
			Utility.Wait(0.05)
		endIf
	endIf
	Utility.Wait(0.05)
Endfunction
; Unequip extra hard, because Skyrim is dumb
function UnequipSomeMore(Actor target, Bool stripArmor, Bool stripWeapons)
	if !target || target == none
		return
	endIf
	if stripArmor
		int s = 0
		while s < armorSlots.length
			Armor wornArmor = JFormDB.GetForm(target, ".CFForm.StrippedArmor" + s) as Armor
			if wornArmor
				target.UnequipItem(wornArmor, true, true)
				Utility.Wait(0.05)
			endIf
			s += 1
		endWhile
	endif
	if stripWeapons
		Form aHand = target.GetEquippedObject(0)
		if aHand
			CreatureFrameworkUtil.GenericUnequip(target, aHand, true, 0, 3)
			Utility.Wait(0.05)
		endIf
		aHand = target.GetEquippedObject(1)
		if aHand
			CreatureFrameworkUtil.GenericUnequip(target, aHand, true, 1, 3)
		endIf
	endif
endFunction
