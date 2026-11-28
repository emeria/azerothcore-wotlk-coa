#include "Chat.h"
#include "CommandScript.h"
#include "Config.h"
#include "GameObject.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptMgr.h"
#include <atomic>
#include <string_view>

using namespace Acore::ChatCommands;

namespace
{
    constexpr std::string_view CatchAddonMessage = "CoaFish\tcatch";

    std::atomic<bool> Enabled{ true };
    std::atomic<bool> AutoHook{ false };

    GameObject* FindOwnBobber(Player* player)
    {
        ObjectGuid const bobberGuid = player->GetGuidValue(UNIT_FIELD_CHANNEL_OBJECT);
        if (!bobberGuid.IsGameObject())
            return nullptr;

        GameObject* bobber = ObjectAccessor::GetGameObject(*player, bobberGuid);
        if (!bobber || bobber->GetGoType() != GAMEOBJECT_TYPE_FISHINGNODE || bobber->GetOwnerGUID() != player->GetGUID())
            return nullptr;

        return bobber;
    }

    void UseBobber(Player* player, GameObject* bobber)
    {
        if (!bobber->IsWithinDistInMap(player, bobber->GetInteractionDistance()))
            return;

        if (player->m_mover != player)
            return;

        bobber->Use(player);
    }

    void Catch(Player* player)
    {
        if (!Enabled)
            return;

        GameObject* bobber = FindOwnBobber(player);
        if (!bobber)
            return;

        LootState const state = bobber->getLootState();
        if (state != GO_READY && state != GO_NOT_READY)
            return;

        UseBobber(player, bobber);
    }
}

class OneKeyFishingWorld : public WorldScript
{
public:
    OneKeyFishingWorld() : WorldScript("OneKeyFishingWorld", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        Enabled = sConfigMgr->GetOption<bool>("OneKeyFishing.Enable", true);
        AutoHook = sConfigMgr->GetOption<bool>("OneKeyFishing.AutoHook", false);
    }
};

class OneKeyFishingPlayer : public PlayerScript
{
public:
    OneKeyFishingPlayer() : PlayerScript("OneKeyFishingPlayer", {
        PLAYERHOOK_ON_UPDATE, PLAYERHOOK_CAN_PLAYER_USE_PRIVATE_CHAT }) { }

    void OnPlayerUpdate(Player* player, uint32 /*diff*/) override
    {
        if (!Enabled || !AutoHook)
            return;

        GameObject* bobber = FindOwnBobber(player);
        if (bobber && bobber->getLootState() == GO_READY)
            UseBobber(player, bobber);
    }

    bool OnPlayerCanUseChat(Player* player, uint32 type, uint32 language, std::string& msg, Player* receiver) override
    {
        if (type != CHAT_MSG_WHISPER || language != LANG_ADDON || receiver != player || msg != CatchAddonMessage)
            return true;

        Catch(player);
        return false;
    }
};

class OneKeyFishingCommand : public CommandScript
{
public:
    OneKeyFishingCommand() : CommandScript("OneKeyFishingCommand") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandTable =
        {
            { "fish", HandleFish, SEC_PLAYER, Console::No },
        };
        return commandTable;
    }

    static bool HandleFish(ChatHandler* handler)
    {
        if (Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr)
            Catch(player);
        return true;
    }
};

void AddSC_coa_one_key_fishing()
{
    new OneKeyFishingWorld();
    new OneKeyFishingPlayer();
    new OneKeyFishingCommand();
}
