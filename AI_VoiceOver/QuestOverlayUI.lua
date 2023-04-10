setfenv(1, VoiceOver)
QuestOverlayUI = {}
QuestOverlayUI.__index = QuestOverlayUI

function QuestOverlayUI:new(soundQueue)
    local questOverlayUI = {}
    setmetatable(questOverlayUI, QuestOverlayUI)

    questOverlayUI.soundQueue = soundQueue
    questOverlayUI.questPlayButtons = {}
    questOverlayUI.playingStates = {}
    questOverlayUI.displayedButtons = {}
    return questOverlayUI
end

function QuestOverlayUI:createPlayButton(questID)
    local playButton = CreateFrame("Button", nil, QuestLogFrame)
    playButton:SetWidth(20)
    playButton:SetHeight(20)
    playButton:SetHitRectInsets(2, 2, 2, 2)
    playButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    playButton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    playButton:GetDisabledTexture():SetDesaturated(true)
    playButton:GetDisabledTexture():SetAlpha(0.33)
    playButton:SetHighlightTexture("Interface\\BUTTONS\\UI-Panel-MinimizeButton-Highlight")
    self.questPlayButtons[questID] = playButton
end

function QuestOverlayUI:updateQuestTitle(questLogTitleFrame, playButton, normalText, questCheck)
    playButton:SetPoint("LEFT", normalText, "LEFT", 4, 0)

    local formatedText = [[|TInterface\AddOns\AI_VoiceOver\Textures\spacer:1:24|t]] .. (normalText:GetText() or ""):trim()

    normalText:SetText(formatedText)
    QuestLogDummyText:SetText(formatedText)

    questCheck:SetPoint("LEFT", normalText, "LEFT", normalText:GetStringWidth(), 0)
end

function QuestOverlayUI:updatePlayButtonTexture(questID, isPlaying)
    local texturePath = isPlaying and "Interface\\TIMEMANAGER\\ResetButton" or
    "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"

    if self.questPlayButtons[questID] then
        self.questPlayButtons[questID]:SetNormalTexture(texturePath)
    end
end

function QuestOverlayUI:updatePlayButton(soundTitle, questID, questLogTitleFrame, normalText, questCheck)
    self.questPlayButtons[questID]:SetParent(questLogTitleFrame:GetParent())
    self.questPlayButtons[questID]:SetFrameLevel(questLogTitleFrame:GetFrameLevel() + 2)

    QuestOverlayUI:updateQuestTitle(questLogTitleFrame, self.questPlayButtons[questID], normalText, questCheck)

    local questOverlayUI = self
    self.questPlayButtons[questID]:SetScript("OnClick", function(self)
        if questOverlayUI.questPlayButtons[questID].soundData == nil then
            local npcID = DataModules:GetQuestLogNPCID(questID)
            questOverlayUI.questPlayButtons[questID].soundData = {
                event = "accept",
                questId = questID,
                name = npcID and DataModules:GetNPCName(npcID) or "Unknown Name",
                title = soundTitle,
                unitGuid = npcID and VoiceOverUtils:getGuidFromId(npcID)
            }
        end

        local button = self
        local soundData = button.soundData
        local questID = soundData.questId
        local isPlaying = questOverlayUI.playingStates[questID] or false

        if not isPlaying then
            questOverlayUI.soundQueue:addSoundToQueue(soundData)
            questOverlayUI.playingStates[questID] = true
            questOverlayUI:updatePlayButtonTexture(questID, true)

            soundData.stopCallback = function()
                questOverlayUI.playingStates[questID] = false
                questOverlayUI:updatePlayButtonTexture(questID, false)
                button.soundData = nil
            end
        else
            questOverlayUI.soundQueue:removeSoundFromQueue(soundData)
        end
    end)
end


function QuestOverlayUI:updateQuestOverlayUI()
    local numEntries, numQuests = GetNumQuestLogEntries()

    -- Hide all buttons in displayedButtons
    for _, button in pairs(self.displayedButtons) do
        button:Hide()
    end

    if numEntries == 0 then
        return
    end

    -- Clear displayedButtons
    table.wipe(self.displayedButtons)

    -- Traverse through the quests displayed in the UI
    for i = 1, QUESTS_DISPLAYED do
        local questIndex = i + VoiceOverUtils:getQuestLogScrollOffset();
        if questIndex > numEntries then
            break
        end

        -- Get quest title
        local questLogTitleFrame = VoiceOverUtils:getQuestLogTitleFrame(i)
        local normalText = VoiceOverUtils:getQuestLogTitleNormalText(i)
        local questCheck = VoiceOverUtils:getQuestLogTitleCheck(i)
        local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID = GetQuestLogTitle(
            questIndex)

        if not self.questPlayButtons[questID] then
            self:createPlayButton(questID)
        end

        if not isHeader then
            if DataModules:PrepareSound({ event = "accept", questId = questID }) then
                self:updatePlayButton(title, questID, questLogTitleFrame, normalText, questCheck)
                self.questPlayButtons[questID]:Enable()
            else
                self:updateQuestTitle(questLogTitleFrame, self.questPlayButtons[questID], normalText, questCheck)
                self.questPlayButtons[questID]:Disable()
            end

            self.questPlayButtons[questID]:Show()
            local isPlaying = self.playingStates[questID] or false
            self:updatePlayButtonTexture(questID, isPlaying)

            -- Add the button to displayedButtons
            table.insert(self.displayedButtons, self.questPlayButtons[questID])
        end
    end
end
