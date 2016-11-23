local QuestManager = require("managers.quest.quest_manager")
local ObjectManager = require("managers.object.object_manager")
local SpawnMobiles = require("utils.spawn_mobiles")

local OLD_MAN_GREETING_STRING = "@quest/force_sensitive/intro:oldman_greeting"
local OLD_MAN_DESPAWN_TIME = 10 * 1000
local OLD_MAN_FORCE_CRYSTAL_STRING = "object/tangible/loot/quest/force_sensitive/force_crystal.iff"
local OLD_MAN_FORCE_CRYSTAL_ID_STRING = "force_crystal_id"

OldManIntroEncounter = Encounter:new {
	-- Task properties
	taskName = "OldManIntroEncounter",
	-- Encounter properties
	encounterDespawnTime = 5 * 60 * 1000, -- 5 minutes
	despawnMessage = "@quest/force_sensitive/intro:leave",
	spawnObjectList = {
		{ template = "old_man", minimumDistance = 64, maximumDistance = 96, referencePoint = 0, followPlayer = true, setNotAttackable = true, runOnDespawn = true }
	},
	onEncounterSpawned = nil,
	isEncounterFinished = nil,
	onEncounterInRange = nil,
	inRangeValue = 16,
}

-- Handling of the encounter in range event.
-- Send the greeting string from the old man and activate the old man quest.
-- @param pCreatureObject pointer to the creature object of the player.
-- @param oldManPointerList a list with a pointer to the old man.
function OldManIntroEncounter:onEncounterInRange(pCreatureObject, oldManPointerList)
	if (pCreatureObject == nil or oldManPointerList == nil or oldManPointerList[1] == nil) then
		return
	end

	local greetingString = LuaStringIdChatParameter(OLD_MAN_GREETING_STRING)
	greetingString:setTT(CreatureObject(pCreatureObject):getFirstName())
	spatialChat(oldManPointerList[1], greetingString:_getObject())

	FsIntro:setCurrentStep(pCreatureObject, 2)
	QuestManager.activateQuest(pCreatureObject, QuestManager.quests.OLD_MAN_INITIAL)
end

-- Event handler for the scheduled despawn of the old man when the player has finished the conversation.
-- @param pCreatureObject pointer to the creatureObject of the player.
function OldManIntroEncounter:handleScheduledDespawn(pCreatureObject)
	if (pCreatureObject == nil) then
		return
	end

	self:handleDespawnEvent(pCreatureObject)
end

-- Schedule despawn of old man due to player conversation has ended.
-- @param pCreatureObject pointer to the creature object of the player.
function OldManIntroEncounter:scheduleDespawnOfOldMan(pCreatureObject)
	if (pCreatureObject == nil) then
		return
	end

	Logger:log("Scheduling despawn of old man.", LT_INFO)
	createEvent(OLD_MAN_DESPAWN_TIME, "OldManIntroEncounter", "handleScheduledDespawn", pCreatureObject, "")
end

-- Give the force crystal to the player.
-- @param pCreatureObject pointer to the creature object of the player.
function OldManIntroEncounter:giveForceCrystalToPlayer(pCreatureObject)
	if (pCreatureObject == nil) then
		return
	end

	Logger:log("Giving crystal to player.", LT_INFO)

	local pInventory = SceneObject(pCreatureObject):getSlottedObject("inventory")

	if (pInventory == nil) then
		return
	end

	local pCrystal = giveItem(pInventory, OLD_MAN_FORCE_CRYSTAL_STRING, -1)

	if (pCrystal ~= nil) then
		CreatureObject(pCreatureObject):removeScreenPlayState(0xFFFFFFFFFFFFFFFF, self.taskName .. OLD_MAN_FORCE_CRYSTAL_ID_STRING)
		CreatureObject(pCreatureObject):setScreenPlayState(SceneObject(pCrystal):getObjectID(), self.taskName .. OLD_MAN_FORCE_CRYSTAL_ID_STRING)

		VillageJediManagerCommon.setJediProgressionScreenPlayState(pCreatureObject, VILLAGE_JEDI_PROGRESSION_HAS_CRYSTAL)
		QuestManager.completeQuest(pCreatureObject, QuestManager.quests.OLD_MAN_INITIAL)
		QuestManager.completeQuest(pCreatureObject, QuestManager.quests.OLD_MAN_FORCE_CRYSTAL)
		CreatureObject(pCreatureObject):sendSystemMessage("@quest/force_sensitive/intro:crystal_message")
	end
end

function OldManIntroEncounter:hasForceCrystal(pCreatureObject)
	local forceCrystalId = CreatureObject(pCreatureObject):getScreenPlayState(self.taskName .. OLD_MAN_FORCE_CRYSTAL_ID_STRING)
	local pForceCrystal = getSceneObject(forceCrystalId)

	return pForceCrystal ~= nil
end

-- Remove the force crystal from the player.
-- @param pCreatureObject pointer to the creature object of the player.
function OldManIntroEncounter:removeForceCrystalFromPlayer(pCreatureObject)
	if (pCreatureObject == nil) then
		return
	end

	Logger:log("Removing crystal from player.", LT_INFO)
	local forceCrystalId = CreatureObject(pCreatureObject):getScreenPlayState(self.taskName .. OLD_MAN_FORCE_CRYSTAL_ID_STRING)
	local pForceCrystal = getSceneObject(forceCrystalId)

	if pForceCrystal ~= nil then
		SceneObject(pForceCrystal):destroyObjectFromWorld()
		SceneObject(pForceCrystal):destroyObjectFromDatabase()
	end

	CreatureObject(pCreatureObject):removeScreenPlayState(0xFFFFFFFFFFFFFFFF, self.taskName .. OLD_MAN_FORCE_CRYSTAL_ID_STRING)

	QuestManager.resetQuest(pCreatureObject, QuestManager.quests.OLD_MAN_INITIAL)
	QuestManager.resetQuest(pCreatureObject, QuestManager.quests.OLD_MAN_FORCE_CRYSTAL)
end

-- Check if the player is conversing with the old man that is spawned for the player
-- @param pConversingPlayer pointer to the creature object of the player.
-- @param pConversingOldMan pointer to the creature object of the conversing old man.
-- @return true if the old man belongs to the player.
function OldManIntroEncounter:doesOldManBelongToThePlayer(pConversingPlayer, pConversingOldMan)
	if (pConversingPlayer == nil or pConversingOldMan == nil) then
		return false
	end

	local playerOldMan = SpawnMobiles.getSpawnedMobiles(pConversingPlayer, OldManIntroEncounter.taskName)

	if playerOldMan ~= nil and playerOldMan[1] ~= nil and #playerOldMan == 1 then
		return SceneObject(pConversingOldMan):getObjectID() == SceneObject(playerOldMan[1]):getObjectID()
	else
		return false
	end
end

-- Check if the old man encounter is finished or not.
-- @param pCreatureObject pointer to the creature object of the player.
-- @return true if the encounter is finished. I.e. the player has the crystal.
function OldManIntroEncounter:isEncounterFinished(pCreatureObject)
	if (pCreatureObject == nil) then
		return
	end

	return QuestManager.hasCompletedQuest(pCreatureObject, QuestManager.quests.OLD_MAN_FORCE_CRYSTAL)
end

-- Handling of finishing the encounter.
-- @param pCreatureObject pointer to the creature object of the player.
function OldManIntroEncounter:taskFinish(pCreatureObject)
	if (pCreatureObject == nil) then
		return true
	end
	
	local oldManVisits = readScreenPlayData(pCreatureObject, "VillageJediProgression", "FsIntroOldManVisits")
	
	if (oldManVisits == "") then
		oldManVisits = 1
	else
		oldManVisits = tonumber(oldManVisits) + 1
	end
	
	writeScreenPlayData(pCreatureObject, "VillageJediProgression", "FsIntroOldManVisits", oldManVisits)

	if (self:isEncounterFinished(pCreatureObject)) then
		FsIntro:startStepDelay(pCreatureObject, 3)
	else
		QuestManager.resetQuest(pCreatureObject, QuestManager.quests.OLD_MAN_INITIAL)
		FsIntro:startStepDelay(pCreatureObject, 1)
	end

	return true
end

return OldManIntroEncounter
