# Vencord DM Plugins

Two Vencord plugins for Discord DMs, installed together in one build.

| Plugin | What it does |
| --- | --- |
| [BulkDeleteDm](https://github.com/Harishisonline/vencord-bulk-delete-dm) | Delete your own messages from a DM in bulk. Handles thousands of messages, paces itself around Discord's rate limit, and can be cancelled mid-run. |
| [FloodDM](https://github.com/Harishisonline/vencord-flood-dm) | Send the same message many times in a DM. Takes the message from a box, paces itself around Discord's rate limit, and can be cancelled mid-run. |

Both are ordinary Vencord user plugins. They work in 1:1 DMs and in group
DMs, and both start enabled.

## Install

Vencord has no runtime plugin folder. A user plugin has to be compiled into
the Vencord bundle, so installing means rebuilding Vencord once. This script
does the whole thing, including fetching both plugins.

```bash
git clone https://github.com/Harishisonline/vencord-dm-plugins.git
cd vencord-dm-plugins
./install.sh
```

The script detects whether you use the regular Vencord installer or the
standalone Vencord that ships with Discord for Mac. Force it if the
detection is wrong:

```bash
./install.sh --standalone   # Discord for Mac (standalone Vencord)
./install.sh --regular      # regular Vencord (Windows, Linux, Mac installer)
```

Requirements: `git`, `node` (20 or newer), and `pnpm`. See
[Vencord's install guide](https://docs.vencord.dev/installing) for how to
get those. On macOS, `corepack enable` gives you `pnpm` if you do not have
it.

Restart Discord afterwards. Both plugins appear under **Settings >
Plugins**, and they start enabled.

### After a Vencord update

Vencord's auto-updater replaces `renderer.js` with the official build, which
does not contain these plugins, so they disappear until you install again.
Re-run the script. The script prints this reminder every time it runs.

## Installing just one plugin

Each plugin has its own repository and its own installer, if you only want
one of them:

- https://github.com/Harishisonline/vencord-bulk-delete-dm
- https://github.com/Harishisonline/vencord-flood-dm

All three installers share one Vencord checkout, so they compose. Installing
one plugin does not remove the other: whatever is already in the shared
checkout gets built again. That means the order does not matter, and running
the individual installer after the combined one keeps both.

## What the two plugins do not do

- **They do not delete anyone else's messages.** BulkDeleteDm only touches
  messages you wrote.
- **They do not bypass Discord's rate limits.** They work inside them. A
  flood of 150 messages takes about 4 minutes, because that is the rate
  Discord allows.
- **They are not bots and they do not join your DMs.** They act as you, from
  inside the client you are already logged into.
- **They cannot undo anything.** Discord's delete is a hard delete, and a
  sent message cannot be recalled.

## Troubleshooting

**A plugin disappeared after a Vencord update.** Run `./install.sh` again.

**The setting says a value but the behaviour is different.** Both plugins
show the value that is actually in use underneath each field, labelled
"Currently saved". Read that, not the number in the box.

**A flood is slower than expected.** That is Discord's write rate limit. A
150 message flood takes about 4 minutes at 0.6 to 0.8 messages per second.
The progress window shows the live rate.

**The install script cannot find Discord.** Point it at the install
directory with `VENCORD_USER_DATA_DIR`, for example
`VENCORD_USER_DATA_DIR="$HOME/Library/Application Support/Vencord"`.

## Safety

- Each plugin acts only on the DM you right-clicked.
- BulkDeleteDm only deletes messages you wrote, and asks for confirmation
  first by default.
- FloodDM sends exactly the text you typed, and can be stopped at any point.
- Discord's own rules still apply, and you are responsible for your account.

## Disclaimer

These are unofficial plugins and are not affiliated with Discord or Vencord.
They use the same API calls the Discord client itself makes. Use them on your
own account and only where it is wanted.

## License

GPL-3.0. See [LICENSE](LICENSE).
