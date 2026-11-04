-- ====================================================================
-- Delirium-Fix: Common Sense (BB_CommonSense) for B42.13+
-- This file NEUTRALIZES the original BB_CS_OnCraft.lua
-- ====================================================================

-- The original mod's OnCraft hook crashes when opening cans with
-- knives or spoons because it uses old character methods.
-- We neutralize it to restore vanilla B42 canning logic.

print("[DelFix] BB_CS_OnCraft neutralized.")
