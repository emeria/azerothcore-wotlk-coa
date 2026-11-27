-- Arakkoa (race 79) could not be created: "Error creating character".
--
-- ChrRaces.dbc (Data\dbc_races) has Arakkoa as playable, Alliance, Human faction, displays 977507/977508,
-- but no SQL gave it start data. rev_20261010_11_custom_races.sql goes from Jinyu (78) to Darkfallen (80).
-- With no playercreateinfo row the server rejects the new character.
--
-- Arakkoa gets the same rows as Jinyu, its nearest match (Alliance, Human faction, Human template, Northshire
-- start, same classes), and the model size rows Jinyu's displays got. The rows are copied from race 78 when
-- this file runs, so it has to sort after every file that writes Jinyu start data.
-- Safe to run again: it only touches race 79 and displays 977507/977508.

START TRANSACTION;

DELETE FROM `playercreateinfo` WHERE `race` = 79;
DELETE FROM `playercreateinfo_item` WHERE `race` = 79;
DELETE FROM `playercreateinfo_action` WHERE `race` = 79;
DELETE FROM `player_race_stats` WHERE `Race` = 79;
DELETE FROM `ascension_custom_class_race` WHERE `race` = 79;

INSERT INTO `playercreateinfo` SELECT 79, `class`, `map`, `zone`, `position_x`, `position_y`, `position_z`, `orientation`
  FROM `playercreateinfo` WHERE `race` = 78;
INSERT INTO `playercreateinfo_item` SELECT 79, `class`, `itemid`, `amount`, `Note`
  FROM `playercreateinfo_item` WHERE `race` = 78;
INSERT INTO `playercreateinfo_action` SELECT 79, `class`, `button`, `action`, `type`
  FROM `playercreateinfo_action` WHERE `race` = 78;
INSERT INTO `player_race_stats` SELECT 79, `Strength`, `Agility`, `Stamina`, `Intellect`, `Spirit`
  FROM `player_race_stats` WHERE `Race` = 78;
INSERT INTO `ascension_custom_class_race` (`class`, `race`) SELECT `class`, 79
  FROM `ascension_custom_class_race` WHERE `race` = 78;

DELETE FROM `creature_model_info` WHERE `DisplayID` IN (977507, 977508);
INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`)
  SELECT 977507, `BoundingRadius`, `CombatReach`, 0, 0 FROM `creature_model_info` WHERE `DisplayID` = 977495;
INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`)
  SELECT 977508, `BoundingRadius`, `CombatReach`, 1, 0 FROM `creature_model_info` WHERE `DisplayID` = 977496;

COMMIT;
