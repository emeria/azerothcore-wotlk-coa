# CoA one-key fishing

On 3.3.5 a fish is caught by clicking the bobber, and an addon cannot click it. This module lets the server do the
click: a catch request uses the player's own fishing bobber exactly as a click on it would.

- After a bite, the request catches the fish and opens the loot window.
- Before a bite, the request does what an early click does: the fish gets away.
- With no bobber out, or while the loot window is open, the request does nothing.
- Only the bobber the player cast is ever used.

## Sending a catch request

### Addon message

| Field | Value |
|---|---|
| Prefix | `CoaFish` |
| Text | `catch` |
| Channel | `WHISPER` |
| Target | the player's own name |

```lua
SendAddonMessage("CoaFish", "catch", "WHISPER", UnitName("player"))
```

The server swallows the message, so nothing shows in chat and no addon receives it back. Any other text with the
`CoaFish` prefix is passed through untouched and is free for future use.

### Chat command

`.fish` does the same for any player, GM or not, and works in a plain macro without the addon:

```
/run SendChatMessage(".fish", "SAY")
```

Typing `.fish` in chat also works.

## Settings

`conf/mod-coa-one-key-fishing.conf.dist`:

| Setting | Default | Effect |
|---|---|---|
| `OneKeyFishing.Enable` | `1` | `0` turns both the addon message and `.fish` off. |
| `OneKeyFishing.AutoHook` | `0` | `1` catches the fish as soon as it bites, with no key press. |

Both settings are read again on `.reload config`.
