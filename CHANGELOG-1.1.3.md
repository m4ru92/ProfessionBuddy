# ProfessionBuddy 1.1.3

Switching between Enchanting and your other profession now works properly.

**Fixes**

- With Enchanting and a second crafting profession (Tailoring, for example), switching between the two misbehaved. The other profession could replace the Enchanting window whenever your bags changed, switching back could close ProfessionBuddy instead of opening the profession, and closing ProfessionBuddy could leave a profession's action bar icon lit. Opening one now closes the other, so only one is ever open at a time.

**Under the hood**

- The code that reads profession windows was reorganised. Nothing you see changes.

No protocol change: 1.1.3 is fully compatible with 1.1.0, 1.1.1, and 1.1.2 clients (COMM_REV unchanged).
