# ProfessionBuddy 1.1.2

Skinning loot on mob tooltips, a mail recipient picker, and two filters that stop showing you things you cannot use.

**New**

- **Skinning loot on the hover tooltip:** hovering a skinnable mob now shows a "Skins into:" list of every item it yields, with the drop chance for each, quality-coloured and with stack ranges. A Nagrand clefthoof reads Knothide Leather Scraps 65%, Knothide Leather 25%, Thick Clefthoof Leather 10%. Quest-only drops are listed but greyed and deliberately carry no percentage, because the underlying value is the chance while you are on the quest rather than the rate you would actually see. Built from the same cmangos data the gather feature already uses, and shown only if you have Skinning. Toggle it with "Skinning loot" in the options.
- **Mail recipient picker:** a "PB" button beside the mail To field opens your saved contacts, favorites first, and fills the recipient in one click.
- **Order source: board vs direct.** Orders claimed from the guild board now carry a "board" tag next to the existing Friend and Guild badge, so you can tell a board claim from an order somebody sent you directly.

**Fixes**

- The reagent tooltip listed recipes only the opposite faction can obtain. On a Horde character, Tender Crocolisk Meat offered Crocolisk Gumbo, which is Alliance-only. The recipe browser had always hidden these; the tooltip never did. Both now follow one rule, and a new "Hide opposite-faction recipes" option turns it off if you want to see the other side's recipes.
- The mail button sat at the wrong height under ElvUI.
- The login profession scan no longer errors on clients that have no skill-line API.

No protocol change: 1.1.2 is fully compatible with 1.1.0 and 1.1.1 clients (COMM_REV unchanged).
