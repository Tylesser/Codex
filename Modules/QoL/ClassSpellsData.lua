local addonName, ns = ...

-- Every spell each class learns from its trainer: { spellID, level, rank, talent, raceMask }, from the
-- SkillLineAbility / SpellLevels / Spell / Talent DB2 tables of WoW Forever build 1.60.1.70959, as served by
-- wago.tools. talent = 1: a higher rank of a talent, or a spell the tables don't tie to the trainer (shown
-- only once a spell of that name is known); raceMask 0 = every race. Do not edit by hand: run
-- tools/data/class_spells.py.
ns.CLASS_SPELLS_BUILD = "1.60.1.70959"
ns.CLASS_SPELLS = {
  DRUID = {
    { 8921, 4, 1 }, -- Moonfire 1
    { 774, 4, 1 }, -- Rejuvenation 1
    { 3025, 6, 0 }, -- Cat Form (Passive)
    { 467, 6, 1 }, -- Thorns 1
    { 5177, 6, 2 }, -- Wrath 2
    { 339, 8, 1 }, -- Entangling Roots 1
    { 5186, 8, 2 }, -- Healing Touch 2
    { 5487, 10, 0 }, -- Bear Form
    { 1178, 10, 0 }, -- Bear Form (Passive)
    { 21178, 10, 0 }, -- Bear Form (Passive2)
    { 99, 10, 1 }, -- Demoralizing Roar 1
    { 6795, 10, 0 }, -- Growl
    { 5232, 10, 2 }, -- Mark of the Wild 2
    { 6807, 10, 1 }, -- Maul 1
    { 8924, 10, 2 }, -- Moonfire 2
    { 1058, 10, 2 }, -- Rejuvenation 2
    { 18960, 10, 0 }, -- Teleport: Moonglade
    { 5229, 12, 0 }, -- Enrage
    { 8936, 12, 1 }, -- Regrowth 1
    { 437138, 12, 1 }, -- Revive 1
    { 5211, 14, 1 }, -- Bash 1
    { 8946, 14, 0 }, -- Cure Poison
    { 5187, 14, 3 }, -- Healing Touch 3
    { 782, 14, 2 }, -- Thorns 2
    { 5178, 14, 3 }, -- Wrath 3
    { 1066, 16, 0 }, -- Aquatic Form
    { 5421, 16, 0 }, -- Aquatic Form (Passive)
    { 8925, 16, 3 }, -- Moonfire 3
    { 1430, 16, 3 }, -- Rejuvenation 3
    { 779, 16, 1 }, -- Swipe 1
    { 1062, 18, 2 }, -- Entangling Roots 2
    { 770, 18, 1 }, -- Faerie Fire 1
    { 2637, 18, 1 }, -- Hibernate 1
    { 6808, 18, 2 }, -- Maul 2
    { 16810, 18, 2, 1 }, -- Nature's Grasp 2
    { 8938, 18, 2 }, -- Regrowth 2
    { 768, 20, 0 }, -- Cat Form
    { 1082, 20, 1 }, -- Claw 1
    { 1735, 20, 2 }, -- Demoralizing Roar 2
    { 5188, 20, 4 }, -- Healing Touch 4
    { 6756, 20, 3 }, -- Mark of the Wild 3
    { 5215, 20, 1 }, -- Prowl 1
    { 20484, 20, 1 }, -- Rebirth 1
    { 1079, 20, 1 }, -- Rip 1
    { 5221, 20, 1 }, -- Shred 1
    { 2912, 20, 1 }, -- Starfire 1
    { 8926, 22, 4 }, -- Moonfire 4
    { 2090, 22, 4 }, -- Rejuvenation 4
    { 2908, 22, 1 }, -- Soothe Animal 1
    { 5179, 22, 4 }, -- Wrath 4
    { 1328618, 24, 1 }, -- Ferocious Bite 1
    { 1822, 24, 1 }, -- Rake 1
    { 8939, 24, 3 }, -- Regrowth 3
    { 2782, 24, 0 }, -- Remove Curse
    { 1237948, 24, 2 }, -- Revive 2
    { 780, 24, 2 }, -- Swipe 2
    { 1075, 24, 3 }, -- Thorns 3
    { 2893, 26, 0 }, -- Abolish Poison
    { 3137, 26, 0 }, -- Abolish Poison Effect
    { 1850, 26, 1 }, -- Dash 1
    { 5189, 26, 5 }, -- Healing Touch 5
    { 6809, 26, 3 }, -- Maul 3
    { 8949, 26, 2 }, -- Starfire 2
    { 5209, 28, 0 }, -- Challenging Roar
    { 3029, 28, 2 }, -- Claw 2
    { 8998, 28, 1 }, -- Cower 1
    { 5195, 28, 3 }, -- Entangling Roots 3
    { 8927, 28, 5 }, -- Moonfire 5
    { 16811, 28, 3, 1 }, -- Nature's Grasp 3
    { 2091, 28, 5 }, -- Rejuvenation 5
    { 9492, 28, 2 }, -- Rip 2
    { 6798, 30, 2 }, -- Bash 2
    { 778, 30, 2 }, -- Faerie Fire 2
    { 24974, 30, 2, 1 }, -- Insect Swarm 2
    { 5234, 30, 4 }, -- Mark of the Wild 4
    { 20739, 30, 2 }, -- Rebirth 2
    { 8940, 30, 4 }, -- Regrowth 4
    { 6800, 30, 2 }, -- Shred 2
    { 740, 30, 1 }, -- Tranquility 1
    { 783, 30, 0 }, -- Travel Form
    { 5180, 30, 5 }, -- Wrath 5
    { 9490, 32, 3 }, -- Demoralizing Roar 3
    { 22568, 32, 2 }, -- Ferocious Bite 2
    { 6778, 32, 6 }, -- Healing Touch 6
    { 1328829, 32, 0 }, -- Poised
    { 6785, 32, 1 }, -- Ravage 1
    { 5225, 32, 0 }, -- Track Humanoids
    { 1328616, 34, 2, 1 }, -- Lacerate 2
    { 8972, 34, 4 }, -- Maul 4
    { 8928, 34, 6 }, -- Moonfire 6
    { 1823, 34, 2 }, -- Rake 2
    { 3627, 34, 6 }, -- Rejuvenation 6
    { 8950, 34, 3 }, -- Starfire 3
    { 769, 34, 3 }, -- Swipe 3
    { 8914, 34, 4 }, -- Thorns 4
    { 22842, 36, 0 }, -- Frenzied Regeneration
    { 9005, 36, 1 }, -- Pounce 1
    { 8941, 36, 5 }, -- Regrowth 5
    { 1237949, 36, 3 }, -- Revive 3
    { 9493, 36, 3 }, -- Rip 3
    { 5201, 38, 3 }, -- Claw 3
    { 5196, 38, 4 }, -- Entangling Roots 4
    { 8903, 38, 7 }, -- Healing Touch 7
    { 18657, 38, 2 }, -- Hibernate 2
    { 16812, 38, 4, 1 }, -- Nature's Grasp 4
    { 8992, 38, 3 }, -- Shred 3
    { 8955, 38, 2 }, -- Soothe Animal 2
    { 6780, 38, 6 }, -- Wrath 6
    { 9000, 40, 2 }, -- Cower 2
    { 9634, 40, 0 }, -- Dire Bear Form
    { 9635, 40, 0 }, -- Dire Bear Form (Passive)
    { 20719, 40, 0 }, -- Feline Grace
    { 22827, 40, 3 }, -- Ferocious Bite 3
    { 16914, 40, 1 }, -- Hurricane 1
    { 29166, 40, 0 }, -- Innervate
    { 24975, 40, 3, 1 }, -- Insect Swarm 3
    { 8907, 40, 5 }, -- Mark of the Wild 5
    { 8929, 40, 7 }, -- Moonfire 7
    { 6783, 40, 2 }, -- Prowl 2
    { 20742, 40, 3 }, -- Rebirth 3
    { 8910, 40, 7 }, -- Rejuvenation 7
    { 8918, 40, 2 }, -- Tranquility 2
    { 9747, 42, 4 }, -- Demoralizing Roar 4
    { 9749, 42, 3 }, -- Faerie Fire 3
    { 9745, 42, 5 }, -- Maul 5
    { 6787, 42, 2 }, -- Ravage 2
    { 9750, 42, 6 }, -- Regrowth 6
    { 8951, 42, 4 }, -- Starfire 4
    { 22812, 44, 0 }, -- Barkskin
    { 9758, 44, 8 }, -- Healing Touch 8
    { 1824, 44, 3 }, -- Rake 3
    { 9752, 44, 4 }, -- Rip 4
    { 9754, 44, 4 }, -- Swipe 4
    { 9756, 44, 5 }, -- Thorns 5
    { 8983, 46, 3 }, -- Bash 3
    { 9821, 46, 2 }, -- Dash 2
    { 9833, 46, 8 }, -- Moonfire 8
    { 9823, 46, 2 }, -- Pounce 2
    { 9839, 46, 8 }, -- Rejuvenation 8
    { 9829, 46, 4 }, -- Shred 4
    { 8905, 46, 7 }, -- Wrath 7
    { 9849, 48, 4 }, -- Claw 4
    { 9852, 48, 5 }, -- Entangling Roots 5
    { 22828, 48, 4 }, -- Ferocious Bite 4
    { 16813, 48, 5, 1 }, -- Nature's Grasp 5
    { 9856, 48, 7 }, -- Regrowth 7
    { 1237950, 48, 4 }, -- Revive 4
    { 21849, 50, 1 }, -- Gift of the Wild 1
    { 9888, 50, 9 }, -- Healing Touch 9
    { 17401, 50, 2 }, -- Hurricane 2
    { 24976, 50, 4, 1 }, -- Insect Swarm 4
    { 1235826, 50, 4, 1 }, -- Lacerate 4
    { 9884, 50, 6 }, -- Mark of the Wild 6
    { 9880, 50, 6 }, -- Maul 6
    { 1238069, 50, 2, 1 }, -- Primal Bite 2
    { 9866, 50, 3 }, -- Ravage 3
    { 20747, 50, 4 }, -- Rebirth 4
    { 9875, 50, 5 }, -- Starfire 5
    { 9862, 50, 3 }, -- Tranquility 3
    { 1238214, 50, 2, 1 }, -- Wild Growth 2
    { 9892, 52, 3 }, -- Cower 3
    { 9898, 52, 5 }, -- Demoralizing Roar 5
    { 9834, 52, 9 }, -- Moonfire 9
    { 9840, 52, 9 }, -- Rejuvenation 9
    { 9894, 52, 5 }, -- Rip 5
    { 9907, 54, 4 }, -- Faerie Fire 4
    { 9904, 54, 4 }, -- Rake 4
    { 9857, 54, 8 }, -- Regrowth 8
    { 9830, 54, 5 }, -- Shred 5
    { 9901, 54, 3 }, -- Soothe Animal 3
    { 9908, 54, 5 }, -- Swipe 5
    { 9910, 54, 6 }, -- Thorns 6
    { 9912, 54, 8 }, -- Wrath 8
    { 22829, 56, 5 }, -- Ferocious Bite 5
    { 9889, 56, 10 }, -- Healing Touch 10
    { 9827, 56, 3 }, -- Pounce 3
    { 9850, 58, 5 }, -- Claw 5
    { 9853, 58, 6 }, -- Entangling Roots 6
    { 18658, 58, 3 }, -- Hibernate 3
    { 1235827, 58, 5, 1 }, -- Lacerate 5
    { 9881, 58, 7 }, -- Maul 7
    { 9835, 58, 10 }, -- Moonfire 10
    { 17329, 58, 6, 1 }, -- Nature's Grasp 6
    { 9867, 58, 4 }, -- Ravage 4
    { 9841, 58, 10 }, -- Rejuvenation 10
    { 9876, 58, 6 }, -- Starfire 6
    { 31018, 60, 6 }, -- Ferocious Bite 6
    { 21850, 60, 2 }, -- Gift of the Wild 2
    { 25297, 60, 11 }, -- Healing Touch 11
    { 17402, 60, 3 }, -- Hurricane 3
    { 24977, 60, 5, 1 }, -- Insect Swarm 5
    { 9885, 60, 7 }, -- Mark of the Wild 7
    { 1238070, 60, 3, 1 }, -- Primal Bite 3
    { 9913, 60, 3 }, -- Prowl 3
    { 20748, 60, 5 }, -- Rebirth 5
    { 9858, 60, 9 }, -- Regrowth 9
    { 25299, 60, 11 }, -- Rejuvenation 11
    { 1237951, 60, 5 }, -- Revive 5
    { 9896, 60, 6 }, -- Rip 6
    { 25298, 60, 7 }, -- Starfire 7
    { 9863, 60, 4 }, -- Tranquility 4
    { 1238215, 60, 3, 1 }, -- Wild Growth 3
  },
  HUNTER = {
    { 13163, 4, 0 }, -- Aspect of the Monkey
    { 1978, 4, 1 }, -- Serpent Sting 1
    { 3044, 6, 1 }, -- Arcane Shot 1
    { 1130, 6, 1 }, -- Hunter's Mark 1
    { 5116, 8, 0 }, -- Concussive Shot
    { 14260, 8, 2 }, -- Raptor Strike 2
    { 13165, 10, 1 }, -- Aspect of the Hawk 1
    { 883, 10, 0 }, -- Call Pet
    { 2641, 10, 0 }, -- Dismiss Pet
    { 6991, 10, 0 }, -- Feed Pet
    { 982, 10, 0 }, -- Revive Pet
    { 13549, 10, 2 }, -- Serpent Sting 2
    { 1515, 10, 0 }, -- Tame Beast
    { 13481, 10, 0 }, -- Tame Beast
    { 19883, 10, 0 }, -- Track Humanoids
    { 14281, 12, 2 }, -- Arcane Shot 2
    { 20736, 12, 1 }, -- Distracting Shot 1
    { 136, 12, 1 }, -- Mend Pet 1
    { 2974, 12, 1 }, -- Wing Clip 1
    { 6197, 14, 0 }, -- Eagle Eye
    { 1002, 14, 0 }, -- Eyes of the Beast
    { 1513, 14, 1 }, -- Scare Beast 1
    { 13795, 16, 1 }, -- Immolation Trap 1
    { 13797, 16, 1 }, -- Immolation Trap 1
    { 1495, 16, 1 }, -- Mongoose Bite 1
    { 14261, 16, 3 }, -- Raptor Strike 3
    { 14318, 18, 2 }, -- Aspect of the Hawk 2
    { 2643, 18, 0 }, -- Multi-Shot
    { 13550, 18, 3 }, -- Serpent Sting 3
    { 19884, 18, 0 }, -- Track Undead
    { 14282, 20, 3 }, -- Arcane Shot 3
    { 5118, 20, 0 }, -- Aspect of the Cheetah
    { 781, 20, 1 }, -- Disengage 1
    { 14274, 20, 2 }, -- Distracting Shot 2
    { 1499, 20, 1 }, -- Freezing Trap 1
    { 3111, 20, 2 }, -- Mend Pet 2
    { 14323, 22, 2 }, -- Hunter's Mark 2
    { 3043, 22, 0 }, -- Scorpid Sting
    { 1462, 24, 0 }, -- Beast Lore
    { 14262, 24, 4 }, -- Raptor Strike 4
    { 19885, 24, 0 }, -- Track Hidden
    { 14302, 26, 2 }, -- Immolation Trap 2
    { 14298, 26, 2 }, -- Immolation Trap 2
    { 3045, 26, 0 }, -- Rapid Fire
    { 13551, 26, 4 }, -- Serpent Sting 4
    { 19880, 26, 0 }, -- Track Elementals
    { 20900, 28, 2, 1 }, -- Aimed Shot 2
    { 14283, 28, 4 }, -- Arcane Shot 4
    { 14319, 28, 3 }, -- Aspect of the Hawk 3
    { 13809, 28, 0 }, -- Frost Trap
    { 3661, 28, 3 }, -- Mend Pet 3
    { 13161, 30, 1 }, -- Aspect of the Beast 1
    { 1242634, 30, 2, 1 }, -- Counterattack 2
    { 15629, 30, 3 }, -- Distracting Shot 3
    { 5384, 30, 0 }, -- Feign Death
    { 24118, 30, 1 }, -- Lacerate 1
    { 14269, 30, 2 }, -- Mongoose Bite 2
    { 14326, 30, 2 }, -- Scare Beast 2
    { 1221404, 32, 0 }, -- Enchanted Flare
    { 1543, 32, 0 }, -- Flare
    { 14263, 32, 5 }, -- Raptor Strike 5
    { 19878, 32, 0 }, -- Track Demons
    { 1299348, 32, 2, 1 }, -- Trueshot Aura 2
    { 14272, 34, 2 }, -- Disengage 2
    { 13813, 34, 1 }, -- Explosive Trap 1
    { 13812, 34, 1 }, -- Explosive Trap 1
    { 13552, 34, 5 }, -- Serpent Sting 5
    { 20901, 36, 3, 1 }, -- Aimed Shot 3
    { 14284, 36, 5 }, -- Arcane Shot 5
    { 14303, 36, 3 }, -- Immolation Trap 3
    { 14299, 36, 3 }, -- Immolation Trap 3
    { 3662, 36, 4 }, -- Mend Pet 4
    { 1293525, 36, 2, 1 }, -- Summon Hawk 2
    { 3034, 36, 1 }, -- Viper Sting 1
    { 14320, 38, 4 }, -- Aspect of the Hawk 4
    { 14267, 38, 2 }, -- Wing Clip 2
    { 1299445, 40, 2 }, -- Aspect of the Beast 2
    { 13159, 40, 0 }, -- Aspect of the Pack
    { 15630, 40, 4 }, -- Distracting Shot 4
    { 14310, 40, 2 }, -- Freezing Trap 2
    { 14324, 40, 3 }, -- Hunter's Mark 3
    { 24119, 40, 2 }, -- Lacerate 2
    { 14264, 40, 6 }, -- Raptor Strike 6
    { 19882, 40, 0 }, -- Track Giants
    { 1510, 40, 1 }, -- Volley 1
    { 20909, 42, 3, 1 }, -- Counterattack 3
    { 13553, 42, 6 }, -- Serpent Sting 6
    { 20902, 44, 4, 1 }, -- Aimed Shot 4
    { 14285, 44, 6 }, -- Arcane Shot 6
    { 14316, 44, 2 }, -- Explosive Trap 2
    { 14314, 44, 2 }, -- Explosive Trap 2
    { 13542, 44, 5 }, -- Mend Pet 5
    { 14270, 44, 3 }, -- Mongoose Bite 3
    { 20043, 46, 1 }, -- Aspect of the Wild 1
    { 14304, 46, 4 }, -- Immolation Trap 4
    { 14300, 46, 4 }, -- Immolation Trap 4
    { 14327, 46, 3 }, -- Scare Beast 3
    { 14279, 46, 2 }, -- Viper Sting 2
    { 14321, 48, 5 }, -- Aspect of the Hawk 5
    { 14273, 48, 3 }, -- Disengage 3
    { 14265, 48, 7 }, -- Raptor Strike 7
    { 1310785, 48, 2, 1 }, -- Sniper Shot 2
    { 1293526, 48, 3, 1 }, -- Summon Hawk 3
    { 1299446, 50, 3 }, -- Aspect of the Beast 3
    { 3674, 50, 1 }, -- Black Arrow 1
    { 15631, 50, 5 }, -- Distracting Shot 5
    { 24120, 50, 3 }, -- Lacerate 3
    { 13554, 50, 7 }, -- Serpent Sting 7
    { 19879, 50, 0 }, -- Track Dragonkin
    { 20905, 50, 4, 1 }, -- Trueshot Aura 4
    { 14294, 50, 2 }, -- Volley 2
    { 20903, 52, 5, 1 }, -- Aimed Shot 5
    { 14286, 52, 7 }, -- Arcane Shot 7
    { 13543, 52, 6 }, -- Mend Pet 6
    { 20910, 54, 4, 1 }, -- Counterattack 4
    { 14317, 54, 3 }, -- Explosive Trap 3
    { 14315, 54, 3 }, -- Explosive Trap 3
    { 20190, 56, 2 }, -- Aspect of the Wild 2
    { 14305, 56, 5 }, -- Immolation Trap 5
    { 14301, 56, 5 }, -- Immolation Trap 5
    { 14266, 56, 8 }, -- Raptor Strike 8
    { 14280, 56, 3 }, -- Viper Sting 3
    { 14322, 58, 6 }, -- Aspect of the Hawk 6
    { 14325, 58, 4 }, -- Hunter's Mark 4
    { 14271, 58, 4 }, -- Mongoose Bite 4
    { 13555, 58, 8 }, -- Serpent Sting 8
    { 1310786, 58, 3, 1 }, -- Sniper Shot 3
    { 14295, 58, 3 }, -- Volley 3
    { 20904, 60, 6, 1 }, -- Aimed Shot 6
    { 14287, 60, 8 }, -- Arcane Shot 8
    { 1299447, 60, 4 }, -- Aspect of the Beast 4
    { 469145, 60, 0 }, -- Aspect of the Falcon
    { 25296, 60, 7 }, -- Aspect of the Hawk 7
    { 14296, 60, 2 }, -- Black Arrow 2
    { 15632, 60, 6 }, -- Distracting Shot 6
    { 14311, 60, 3 }, -- Freezing Trap 3
    { 24406, 60, 0, 1 }, -- Improved Mend Pet
    { 1299332, 60, 4, 1 }, -- Lacerate 4
    { 13544, 60, 7 }, -- Mend Pet 7
    { 25295, 60, 9 }, -- Serpent Sting 9
    { 1293527, 60, 4, 1 }, -- Summon Hawk 4
    { 19801, 60, 0 }, -- Tranquilizing Shot
    { 20906, 60, 5, 1 }, -- Trueshot Aura 5
    { 14268, 60, 3 }, -- Wing Clip 3
  },
  MAGE = {
    { 5504, 4, 1 }, -- Conjure Water 1
    { 116, 4, 1 }, -- Frostbolt 1
    { 587, 6, 1 }, -- Conjure Food 1
    { 2136, 6, 1 }, -- Fire Blast 1
    { 143, 6, 2 }, -- Fireball 2
    { 5143, 8, 1 }, -- Arcane Missiles 1
    { 205, 8, 2 }, -- Frostbolt 2
    { 118, 8, 1 }, -- Polymorph 1
    { 12536, 10, 0 }, -- Clearcasting
    { 5505, 10, 2 }, -- Conjure Water 2
    { 7300, 10, 2 }, -- Frost Armor 2
    { 122, 10, 1 }, -- Frost Nova 1
    { 12494, 10, 0, 1 }, -- Frostbite
    { 12355, 10, 0, 1 }, -- Impact
    { 597, 12, 2 }, -- Conjure Food 2
    { 604, 12, 1 }, -- Dampen Magic 1
    { 145, 12, 3 }, -- Fireball 3
    { 130, 12, 0 }, -- Slow Fall
    { 1449, 14, 1 }, -- Arcane Explosion 1
    { 1460, 14, 2 }, -- Arcane Intellect 2
    { 2137, 14, 2 }, -- Fire Blast 2
    { 837, 14, 3 }, -- Frostbolt 3
    { 5144, 16, 2 }, -- Arcane Missiles 2
    { 2120, 16, 1 }, -- Flamestrike 1
    { 1008, 18, 1 }, -- Amplify Magic 1
    { 3140, 18, 4 }, -- Fireball 4
    { 475, 18, 0 }, -- Remove Lesser Curse
    { 1953, 20, 0 }, -- Blink
    { 10, 20, 1 }, -- Blizzard 1
    { 5506, 20, 3 }, -- Conjure Water 3
    { 12051, 20, 0 }, -- Evocation
    { 543, 20, 1 }, -- Fire Ward 1
    { 7301, 20, 3 }, -- Frost Armor 3
    { 7322, 20, 4 }, -- Frostbolt 4
    { 1463, 20, 1 }, -- Mana Shield 1
    { 12824, 20, 2 }, -- Polymorph 2
    { 3562, 20, 0, 0, -1321907123 }, -- Teleport: Ironforge
    { 3567, 20, 0, 0, 1309324210 }, -- Teleport: Orgrimmar
    { 3561, 20, 0, 0, -1321907123 }, -- Teleport: Stormwind
    { 3563, 20, 0, 0, 1309324210 }, -- Teleport: Undercity
    { 8437, 22, 2 }, -- Arcane Explosion 2
    { 990, 22, 3 }, -- Conjure Food 3
    { 2138, 22, 3 }, -- Fire Blast 3
    { 6143, 22, 1 }, -- Frost Ward 1
    { 2948, 22, 1 }, -- Scorch 1
    { 5145, 24, 3 }, -- Arcane Missiles 3
    { 2139, 24, 0 }, -- Counterspell
    { 8450, 24, 2 }, -- Dampen Magic 2
    { 8400, 24, 5 }, -- Fireball 5
    { 2121, 24, 2 }, -- Flamestrike 2
    { 12505, 24, 2, 1 }, -- Pyroblast 2
    { 120, 26, 1 }, -- Cone of Cold 1
    { 865, 26, 2 }, -- Frost Nova 2
    { 8406, 26, 5 }, -- Frostbolt 5
    { 1461, 28, 3 }, -- Arcane Intellect 3
    { 6141, 28, 2 }, -- Blizzard 2
    { 759, 28, 0 }, -- Conjure Mana Agate
    { 8494, 28, 2 }, -- Mana Shield 2
    { 8444, 28, 2 }, -- Scorch 2
    { 8455, 30, 2 }, -- Amplify Magic 2
    { 1239696, 30, 2, 1 }, -- Arcane Blast 2
    { 8438, 30, 3 }, -- Arcane Explosion 3
    { 6127, 30, 4 }, -- Conjure Water 4
    { 8412, 30, 4 }, -- Fire Blast 4
    { 8457, 30, 2 }, -- Fire Ward 2
    { 8401, 30, 6 }, -- Fireball 6
    { 7302, 30, 1 }, -- Ice Armor 1
    { 12522, 30, 3, 1 }, -- Pyroblast 3
    { 3565, 30, 0, 0, -1321907123 }, -- Teleport: Darnassus
    { 3566, 30, 0, 0, 1309324210 }, -- Teleport: Thunder Bluff
    { 8416, 32, 4 }, -- Arcane Missiles 4
    { 6129, 32, 4 }, -- Conjure Food 4
    { 8422, 32, 3 }, -- Flamestrike 3
    { 8461, 32, 2 }, -- Frost Ward 2
    { 8407, 32, 6 }, -- Frostbolt 6
    { 8492, 34, 2 }, -- Cone of Cold 2
    { 1240044, 34, 3, 1 }, -- Ice Lance 3
    { 6117, 34, 1 }, -- Mage Armor 1
    { 8445, 34, 3 }, -- Scorch 3
    { 1326080, 36, 2, 1 }, -- Arcane Wrath 2
    { 13018, 36, 2, 1 }, -- Blast Wave 2
    { 8427, 36, 3 }, -- Blizzard 3
    { 8451, 36, 3 }, -- Dampen Magic 3
    { 8402, 36, 7 }, -- Fireball 7
    { 8495, 36, 3 }, -- Mana Shield 3
    { 12523, 36, 4, 1 }, -- Pyroblast 4
    { 8439, 38, 4 }, -- Arcane Explosion 4
    { 3552, 38, 0 }, -- Conjure Mana Jade
    { 8413, 38, 5 }, -- Fire Blast 5
    { 8408, 38, 7 }, -- Frostbolt 7
    { 1239697, 40, 3, 1 }, -- Arcane Blast 3
    { 8417, 40, 5 }, -- Arcane Missiles 5
    { 10138, 40, 5 }, -- Conjure Water 5
    { 8458, 40, 3 }, -- Fire Ward 3
    { 8423, 40, 4 }, -- Flamestrike 4
    { 6131, 40, 3 }, -- Frost Nova 3
    { 7320, 40, 2 }, -- Ice Armor 2
    { 12825, 40, 3 }, -- Polymorph 3
    { 11416, 40, 0, 0, -1321907123 }, -- Portal: Ironforge
    { 11417, 40, 0, 0, 1309324210 }, -- Portal: Orgrimmar
    { 10059, 40, 0, 0, -1321907123 }, -- Portal: Stormwind
    { 11418, 40, 0, 0, 1309324210 }, -- Portal: Undercity
    { 8446, 40, 4 }, -- Scorch 4
    { 10169, 42, 3 }, -- Amplify Magic 3
    { 10156, 42, 4 }, -- Arcane Intellect 4
    { 10159, 42, 3 }, -- Cone of Cold 3
    { 10144, 42, 5 }, -- Conjure Food 5
    { 10148, 42, 8 }, -- Fireball 8
    { 8462, 42, 3 }, -- Frost Ward 3
    { 1240045, 42, 4, 1 }, -- Ice Lance 4
    { 12524, 42, 5, 1 }, -- Pyroblast 5
    { 13019, 44, 3, 1 }, -- Blast Wave 3
    { 10185, 44, 4 }, -- Blizzard 4
    { 10179, 44, 8 }, -- Frostbolt 8
    { 10191, 44, 4 }, -- Mana Shield 4
    { 10201, 46, 5 }, -- Arcane Explosion 5
    { 10197, 46, 6 }, -- Fire Blast 6
    { 13031, 46, 2, 1 }, -- Ice Barrier 2
    { 22782, 46, 2 }, -- Mage Armor 2
    { 10205, 46, 5 }, -- Scorch 5
    { 10211, 48, 6 }, -- Arcane Missiles 6
    { 1326081, 48, 3, 1 }, -- Arcane Wrath 3
    { 10053, 48, 0 }, -- Conjure Mana Citrine
    { 10173, 48, 4 }, -- Dampen Magic 4
    { 10149, 48, 9 }, -- Fireball 9
    { 10215, 48, 5 }, -- Flamestrike 5
    { 1240046, 48, 5, 1 }, -- Ice Lance 5
    { 12525, 48, 6, 1 }, -- Pyroblast 6
    { 1239699, 50, 4, 1 }, -- Arcane Blast 4
    { 10160, 50, 4 }, -- Cone of Cold 4
    { 10139, 50, 6 }, -- Conjure Water 6
    { 10223, 50, 4 }, -- Fire Ward 4
    { 10180, 50, 9 }, -- Frostbolt 9
    { 1237312, 50, 2 }, -- Frostfire Bolt 2
    { 10219, 50, 3 }, -- Ice Armor 3
    { 11419, 50, 0, 0, -1321907123 }, -- Portal: Darnassus
    { 11420, 50, 0, 0, 1309324210 }, -- Portal: Thunder Bluff
    { 1297659, 50, 0, 0, -1321907123 }, -- Teleport: Dalaran
    { 13020, 52, 4, 1 }, -- Blast Wave 4
    { 10186, 52, 5 }, -- Blizzard 5
    { 10145, 52, 6 }, -- Conjure Food 6
    { 10177, 52, 4 }, -- Frost Ward 4
    { 13032, 52, 3, 1 }, -- Ice Barrier 3
    { 10192, 52, 5 }, -- Mana Shield 5
    { 10206, 52, 6 }, -- Scorch 6
    { 10170, 54, 4 }, -- Amplify Magic 4
    { 10202, 54, 6 }, -- Arcane Explosion 6
    { 10199, 54, 7 }, -- Fire Blast 7
    { 10150, 54, 10 }, -- Fireball 10
    { 10230, 54, 4 }, -- Frost Nova 4
    { 12526, 54, 7, 1 }, -- Pyroblast 7
    { 23028, 56, 0 }, -- Arcane Brilliance
    { 10157, 56, 5 }, -- Arcane Intellect 5
    { 10212, 56, 7 }, -- Arcane Missiles 7
    { 25345, 56, 8 }, -- Arcane Missiles 8
    { 10216, 56, 6 }, -- Flamestrike 6
    { 10181, 56, 10 }, -- Frostbolt 10
    { 1240047, 56, 6, 1 }, -- Ice Lance 6
    { 10161, 58, 5 }, -- Cone of Cold 5
    { 10054, 58, 0 }, -- Conjure Mana Ruby
    { 13033, 58, 4, 1 }, -- Ice Barrier 4
    { 22783, 58, 3 }, -- Mage Armor 3
    { 10207, 58, 7 }, -- Scorch 7
    { 1239700, 60, 5, 1 }, -- Arcane Blast 5
    { 1326082, 60, 4, 1 }, -- Arcane Wrath 4
    { 13021, 60, 5, 1 }, -- Blast Wave 5
    { 10187, 60, 6 }, -- Blizzard 6
    { 28612, 60, 7 }, -- Conjure Food 7
    { 10140, 60, 7 }, -- Conjure Water 7
    { 468766, 60, 8 }, -- Conjure Water 8
    { 10174, 60, 5 }, -- Dampen Magic 5
    { 24530, 60, 0 }, -- Felfire
    { 10225, 60, 5 }, -- Fire Ward 5
    { 10151, 60, 11 }, -- Fireball 11
    { 25306, 60, 12 }, -- Fireball 12
    { 28609, 60, 5 }, -- Frost Ward 5
    { 25304, 60, 11 }, -- Frostbolt 11
    { 1237313, 60, 3 }, -- Frostfire Bolt 3
    { 10220, 60, 4 }, -- Ice Armor 4
    { 10193, 60, 6 }, -- Mana Shield 6
    { 28271, 60, 0 }, -- Polymorph
    { 28272, 60, 0 }, -- Polymorph
    { 12826, 60, 4 }, -- Polymorph 4
    { 28270, 60, 0 }, -- Polymorph: Cow
    { 18809, 60, 8, 1 }, -- Pyroblast 8
  },
  PALADIN = {
    { 19740, 4, 1 }, -- Blessing of Might 1
    { 20271, 4, 0 }, -- Judgement
    { 498, 6, 1 }, -- Divine Protection 1
    { 639, 6, 2 }, -- Holy Light 2
    { 679, 6, 1 }, -- Holy Strike 1
    { 21082, 6, 1 }, -- Seal of the Crusader 1
    { 853, 8, 1 }, -- Hammer of Justice 1
    { 1152, 8, 0 }, -- Purify
    { 1022, 10, 1 }, -- Blessing of Protection 1
    { 10290, 10, 2 }, -- Devotion Aura 2
    { 633, 10, 1 }, -- Lay on Hands 1
    { 25780, 10, 0 }, -- Righteous Fury
    { 1311649, 10, 1 }, -- Seal of Fury 1
    { 20287, 10, 2 }, -- Seal of Righteousness 2
    { 19834, 12, 2 }, -- Blessing of Might 2
    { 678, 12, 2 }, -- Holy Strike 2
    { 7328, 12, 1 }, -- Redemption 1
    { 20162, 12, 2 }, -- Seal of the Crusader 2
    { 19742, 14, 1 }, -- Blessing of Wisdom 1
    { 647, 14, 3 }, -- Holy Light 3
    { 7294, 16, 1 }, -- Retribution Aura 1
    { 1044, 18, 0 }, -- Blessing of Freedom
    { 5573, 18, 2 }, -- Divine Protection 2
    { 1311656, 18, 2 }, -- Seal of Fury 2
    { 20288, 18, 3 }, -- Seal of Righteousness 3
    { 643, 20, 3 }, -- Devotion Aura 3
    { 879, 20, 1 }, -- Exorcism 1
    { 19750, 20, 1 }, -- Flash of Light 1
    { 1866, 20, 3 }, -- Holy Strike 3
    { 1310897, 20, 0, 1 }, -- Voice of Truth
    { 19835, 22, 3 }, -- Blessing of Might 3
    { 19746, 22, 0 }, -- Concentration Aura
    { 1026, 22, 4 }, -- Holy Light 4
    { 20164, 22, 0 }, -- Seal of Justice
    { 20305, 22, 3 }, -- Seal of the Crusader 3
    { 5599, 24, 2 }, -- Blessing of Protection 2
    { 19850, 24, 2 }, -- Blessing of Wisdom 2
    { 5588, 24, 2 }, -- Hammer of Justice 2
    { 10322, 24, 2 }, -- Redemption 2
    { 2878, 24, 1 }, -- Turn Undead 1
    { 19939, 26, 2 }, -- Flash of Light 2
    { 10298, 26, 2 }, -- Retribution Aura 2
    { 20163, 26, 3 }, -- Seal of Fury 3
    { 20289, 26, 4 }, -- Seal of Righteousness 4
    { 5614, 28, 2 }, -- Exorcism 2
    { 680, 28, 4 }, -- Holy Strike 4
    { 19876, 28, 1 }, -- Shadow Resistance Aura 1
    { 20116, 30, 2, 1 }, -- Consecration 2
    { 10291, 30, 4 }, -- Devotion Aura 4
    { 19752, 30, 0 }, -- Divine Intervention
    { 1042, 30, 5 }, -- Holy Light 5
    { 2800, 30, 2 }, -- Lay on Hands 2
    { 20915, 30, 2, 1 }, -- Seal of Command 2
    { 20165, 30, 1 }, -- Seal of Light 1
    { 19836, 32, 4 }, -- Blessing of Might 4
    { 19888, 32, 1 }, -- Frost Resistance Aura 1
    { 20306, 32, 4 }, -- Seal of the Crusader 4
    { 19852, 34, 3 }, -- Blessing of Wisdom 3
    { 642, 34, 1 }, -- Divine Shield 1
    { 19940, 34, 3 }, -- Flash of Light 3
    { 20419, 34, 4 }, -- Seal of Fury 4
    { 20290, 34, 5 }, -- Seal of Righteousness 5
    { 5615, 36, 3 }, -- Exorcism 3
    { 19891, 36, 1 }, -- Fire Resistance Aura 1
    { 2495, 36, 5 }, -- Holy Strike 5
    { 10324, 36, 3 }, -- Redemption 3
    { 10299, 36, 3 }, -- Retribution Aura 3
    { 10278, 38, 3 }, -- Blessing of Protection 3
    { 3472, 38, 6 }, -- Holy Light 6
    { 20166, 38, 1 }, -- Seal of Wisdom 1
    { 5627, 38, 2 }, -- Turn Undead 2
    { 20922, 40, 3, 1 }, -- Consecration 3
    { 1032, 40, 5 }, -- Devotion Aura 5
    { 5589, 40, 3 }, -- Hammer of Justice 3
    { 20927, 40, 2, 1 }, -- Holy Shield 2
    { 20918, 40, 3, 1 }, -- Seal of Command 3
    { 20347, 40, 2 }, -- Seal of Light 2
    { 19895, 40, 2 }, -- Shadow Resistance Aura 2
    { 13819, 40, 0, 0, 1029 }, -- Summon Warhorse
    { 1279399, 40, 0 }, -- Summon Warhorse
    { 19837, 42, 5 }, -- Blessing of Might 5
    { 4987, 42, 0 }, -- Cleanse
    { 19941, 42, 4 }, -- Flash of Light 4
    { 20421, 42, 5 }, -- Seal of Fury 5
    { 20291, 42, 6 }, -- Seal of Righteousness 6
    { 20307, 42, 5 }, -- Seal of the Crusader 5
    { 19853, 44, 4 }, -- Blessing of Wisdom 4
    { 10312, 44, 4 }, -- Exorcism 4
    { 19897, 44, 2 }, -- Frost Resistance Aura 2
    { 24275, 44, 1 }, -- Hammer of Wrath 1
    { 5569, 44, 6 }, -- Holy Strike 6
    { 6940, 46, 1 }, -- Blessing of Sacrifice 1
    { 10328, 46, 7 }, -- Holy Light 7
    { 10300, 46, 4 }, -- Retribution Aura 4
    { 19899, 48, 2 }, -- Fire Resistance Aura 2
    { 20929, 48, 3, 1 }, -- Holy Shock 3
    { 20772, 48, 4 }, -- Redemption 4
    { 20356, 48, 2 }, -- Seal of Wisdom 2
    { 20923, 50, 4, 1 }, -- Consecration 4
    { 10292, 50, 6 }, -- Devotion Aura 6
    { 1020, 50, 2 }, -- Divine Shield 2
    { 19942, 50, 5 }, -- Flash of Light 5
    { 20928, 50, 3, 1 }, -- Holy Shield 3
    { 2812, 50, 1 }, -- Holy Wrath 1
    { 10310, 50, 3 }, -- Lay on Hands 3
    { 1311590, 50, 2, 1 }, -- Light's Vigil 2
    { 20919, 50, 4, 1 }, -- Seal of Command 4
    { 20422, 50, 6 }, -- Seal of Fury 6
    { 20348, 50, 3 }, -- Seal of Light 3
    { 20292, 50, 7 }, -- Seal of Righteousness 7
    { 19838, 52, 6 }, -- Blessing of Might 6
    { 10313, 52, 5 }, -- Exorcism 5
    { 25782, 52, 1 }, -- Greater Blessing of Might 1
    { 24274, 52, 2 }, -- Hammer of Wrath 2
    { 10332, 52, 7 }, -- Holy Strike 7
    { 20308, 52, 6 }, -- Seal of the Crusader 6
    { 19896, 52, 3 }, -- Shadow Resistance Aura 3
    { 10326, 52, 3 }, -- Turn Undead 3
    { 20729, 54, 2 }, -- Blessing of Sacrifice 2
    { 19854, 54, 5 }, -- Blessing of Wisdom 5
    { 25894, 54, 1 }, -- Greater Blessing of Wisdom 1
    { 10308, 54, 4 }, -- Hammer of Justice 4
    { 10329, 54, 8 }, -- Holy Light 8
    { 19898, 56, 3 }, -- Frost Resistance Aura 3
    { 20930, 56, 4, 1 }, -- Holy Shock 4
    { 10301, 56, 5 }, -- Retribution Aura 5
    { 19943, 58, 6 }, -- Flash of Light 6
    { 20423, 58, 7 }, -- Seal of Fury 7
    { 20293, 58, 8 }, -- Seal of Righteousness 8
    { 20357, 58, 3 }, -- Seal of Wisdom 3
    { 25291, 60, 7 }, -- Blessing of Might 7
    { 25290, 60, 6 }, -- Blessing of Wisdom 6
    { 20924, 60, 5, 1 }, -- Consecration 5
    { 10293, 60, 7 }, -- Devotion Aura 7
    { 10314, 60, 6 }, -- Exorcism 6
    { 19900, 60, 3 }, -- Fire Resistance Aura 3
    { 25898, 60, 0 }, -- Greater Blessing of Kings
    { 25916, 60, 2 }, -- Greater Blessing of Might 2
    { 25918, 60, 2 }, -- Greater Blessing of Wisdom 2
    { 24239, 60, 3 }, -- Hammer of Wrath 3
    { 25292, 60, 9 }, -- Holy Light 9
    { 1239570, 60, 4, 1 }, -- Holy Shield 4
    { 10333, 60, 8 }, -- Holy Strike 8
    { 10318, 60, 2 }, -- Holy Wrath 2
    { 1311595, 60, 3, 1 }, -- Light's Vigil 3
    { 20773, 60, 5 }, -- Redemption 5
    { 20920, 60, 5, 1 }, -- Seal of Command 5
    { 20349, 60, 4 }, -- Seal of Light 4
    { 23214, 60, 0, 0, 5 }, -- Summon Charger
  },
  PRIEST = {
    { 2052, 4, 2 }, -- Lesser Heal 2
    { 589, 4, 1 }, -- Shadow Word: Pain 1
    { 17, 6, 1 }, -- Power Word: Shield 1
    { 591, 6, 2 }, -- Smite 2
    { 586, 8, 1 }, -- Fade 1
    { 139, 8, 1 }, -- Renew 1
    { 1277455, 10, 0, 0, 64 }, -- Confounding Flash
    { 13908, 10, 1, 0, 4 }, -- Desperate Prayer 1
    { 1277370, 10, 1, 0, 1 }, -- Divine Grace 1
    { 9035, 10, 1, 0, 128 }, -- Hex of Weakness 1
    { 2053, 10, 3 }, -- Lesser Heal 3
    { 8092, 10, 1 }, -- Mind Blast 1
    { 2006, 10, 1 }, -- Resurrection 1
    { 594, 10, 2 }, -- Shadow Word: Pain 2
    { 10797, 10, 1, 0, 8 }, -- Starshards 1
    { 2652, 10, 1, 0, 16 }, -- Touch of Weakness 1
    { 2943, 10, 1, 0, 16 }, -- Touch of Weakness 1
    { 588, 12, 1 }, -- Inner Fire 1
    { 1244, 12, 2 }, -- Power Word: Fortitude 2
    { 592, 12, 2 }, -- Power Word: Shield 2
    { 528, 14, 0 }, -- Cure Disease
    { 8122, 14, 1 }, -- Psychic Scream 1
    { 6074, 14, 2 }, -- Renew 2
    { 598, 14, 3 }, -- Smite 3
    { 2054, 16, 1 }, -- Heal 1
    { 8102, 16, 2 }, -- Mind Blast 2
    { 19236, 18, 2, 0, 4 }, -- Desperate Prayer 2
    { 527, 18, 1 }, -- Dispel Magic 1
    { 1277371, 18, 2, 0, 1 }, -- Divine Grace 2
    { 600, 18, 3 }, -- Power Word: Shield 3
    { 970, 18, 3 }, -- Shadow Word: Pain 3
    { 19296, 18, 2, 0, 8 }, -- Starshards 2
    { 1277331, 20, 1, 0, 4 }, -- Chastise 1
    { 1277462, 20, 1, 0, 64 }, -- Contingency Plan 1
    { 1277324, 20, 1, 0, 16 }, -- Dark Sacrifice 1
    { 2944, 20, 1 }, -- Devouring Plague 1
    { 2651, 20, 0, 0, 8 }, -- Elune's Grace
    { 9578, 20, 2 }, -- Fade 2
    { 6346, 20, 0 }, -- Fear Ward
    { 13896, 20, 1, 0, 1 }, -- Feedback 1
    { 2061, 20, 1 }, -- Flash Heal 1
    { 19281, 20, 2, 0, 128 }, -- Hex of Weakness 2
    { 14914, 20, 1 }, -- Holy Fire 1
    { 23455, 20, 1, 1 }, -- Holy Nova 1
    { 7128, 20, 2 }, -- Inner Fire 2
    { 453, 20, 1 }, -- Mind Soothe 1
    { 6075, 20, 3 }, -- Renew 3
    { 9484, 20, 1 }, -- Shackle Undead 1
    { 18137, 20, 1, 0, 128 }, -- Shadowguard 1
    { 28377, 20, 1, 0, 128 }, -- Shadowguard 1
    { 19261, 20, 2, 0, 16 }, -- Touch of Weakness 2
    { 19249, 20, 2, 0, 16 }, -- Touch of Weakness 2
    { 2055, 22, 2 }, -- Heal 2
    { 8103, 22, 3 }, -- Mind Blast 3
    { 2096, 22, 1 }, -- Mind Vision 1
    { 2010, 22, 2 }, -- Resurrection 2
    { 984, 22, 4 }, -- Smite 4
    { 15262, 24, 2 }, -- Holy Fire 2
    { 8129, 24, 1 }, -- Mana Burn 1
    { 1245, 24, 3 }, -- Power Word: Fortitude 3
    { 3747, 24, 4 }, -- Power Word: Shield 4
    { 19238, 26, 3, 0, 4 }, -- Desperate Prayer 3
    { 1277372, 26, 3, 0, 1 }, -- Divine Grace 3
    { 9472, 26, 2 }, -- Flash Heal 2
    { 6076, 26, 4 }, -- Renew 4
    { 992, 26, 4 }, -- Shadow Word: Pain 4
    { 19299, 26, 3, 0, 8 }, -- Starshards 3
    { 19276, 28, 2 }, -- Devouring Plague 2
    { 6063, 28, 3 }, -- Heal 3
    { 15430, 28, 2, 1 }, -- Holy Nova 2
    { 23458, 28, 2, 1 }, -- Holy Nova 2
    { 8104, 28, 4 }, -- Mind Blast 4
    { 17311, 28, 2, 1 }, -- Mind Flay 2
    { 8124, 28, 2 }, -- Psychic Scream 2
    { 19308, 28, 2, 0, 128 }, -- Shadowguard 2
    { 28378, 28, 2, 0, 128 }, -- Shadowguard 2
    { 1277332, 30, 2, 0, 4 }, -- Chastise 2
    { 1277634, 30, 2, 0, 64 }, -- Contingency Plan 2
    { 1277325, 30, 2, 0, 16 }, -- Dark Sacrifice 2
    { 9579, 30, 3 }, -- Fade 3
    { 19271, 30, 2, 0, 1 }, -- Feedback 2
    { 19282, 30, 3, 0, 128 }, -- Hex of Weakness 3
    { 15263, 30, 3 }, -- Holy Fire 3
    { 602, 30, 3 }, -- Inner Fire 3
    { 605, 30, 1 }, -- Mind Control 1
    { 6065, 30, 5 }, -- Power Word: Shield 5
    { 596, 30, 1 }, -- Prayer of Healing 1
    { 976, 30, 1 }, -- Shadow Protection 1
    { 1004, 30, 5 }, -- Smite 5
    { 19262, 30, 3, 0, 16 }, -- Touch of Weakness 3
    { 19251, 30, 3, 0, 16 }, -- Touch of Weakness 3
    { 552, 32, 0 }, -- Abolish Disease
    { 9473, 32, 3 }, -- Flash Heal 3
    { 8131, 32, 2 }, -- Mana Burn 2
    { 6077, 32, 5 }, -- Renew 5
    { 1309595, 32, 1 }, -- Shadow Word: Death 1
    { 19240, 34, 4, 0, 4 }, -- Desperate Prayer 4
    { 1277374, 34, 4, 0, 1 }, -- Divine Grace 4
    { 6064, 34, 4 }, -- Heal 4
    { 1706, 34, 0 }, -- Levitate
    { 8105, 34, 5 }, -- Mind Blast 5
    { 10880, 34, 3 }, -- Resurrection 3
    { 2767, 34, 5 }, -- Shadow Word: Pain 5
    { 19302, 34, 4, 0, 8 }, -- Starshards 4
    { 19277, 36, 3 }, -- Devouring Plague 3
    { 988, 36, 2 }, -- Dispel Magic 2
    { 15264, 36, 4 }, -- Holy Fire 4
    { 15431, 36, 3, 1 }, -- Holy Nova 3
    { 23459, 36, 3, 1 }, -- Holy Nova 3
    { 17312, 36, 3, 1 }, -- Mind Flay 3
    { 8192, 36, 2 }, -- Mind Soothe 2
    { 2791, 36, 4 }, -- Power Word: Fortitude 4
    { 6066, 36, 6 }, -- Power Word: Shield 6
    { 19309, 36, 3, 0, 128 }, -- Shadowguard 3
    { 28379, 36, 3, 0, 128 }, -- Shadowguard 3
    { 9474, 38, 4 }, -- Flash Heal 4
    { 6078, 38, 6 }, -- Renew 6
    { 6060, 38, 6 }, -- Smite 6
    { 1277333, 40, 3, 0, 4 }, -- Chastise 3
    { 1277638, 40, 3, 0, 64 }, -- Contingency Plan 3
    { 1277326, 40, 3, 0, 16 }, -- Dark Sacrifice 3
    { 14818, 40, 2, 1 }, -- Divine Spirit 2
    { 9592, 40, 4 }, -- Fade 4
    { 19273, 40, 3, 0, 1 }, -- Feedback 3
    { 2060, 40, 1 }, -- Greater Heal 1
    { 19283, 40, 4, 0, 128 }, -- Hex of Weakness 4
    { 1006, 40, 4 }, -- Inner Fire 4
    { 7001, 40, 1 }, -- Lightwell Renew 1
    { 10874, 40, 3 }, -- Mana Burn 3
    { 8106, 40, 6 }, -- Mind Blast 6
    { 1240720, 40, 2, 1 }, -- Penance 2
    { 996, 40, 2 }, -- Prayer of Healing 2
    { 9485, 40, 2 }, -- Shackle Undead 2
    { 1309633, 40, 2 }, -- Shadow Word: Death 2
    { 19264, 40, 4, 0, 16 }, -- Touch of Weakness 4
    { 19252, 40, 4, 0, 16 }, -- Touch of Weakness 4
    { 19241, 42, 5, 0, 4 }, -- Desperate Prayer 5
    { 1277376, 42, 5, 0, 1 }, -- Divine Grace 5
    { 15265, 42, 5 }, -- Holy Fire 5
    { 10898, 42, 7 }, -- Power Word: Shield 7
    { 10888, 42, 3 }, -- Psychic Scream 3
    { 10957, 42, 2 }, -- Shadow Protection 2
    { 10892, 42, 6 }, -- Shadow Word: Pain 6
    { 19303, 42, 5, 0, 8 }, -- Starshards 5
    { 19278, 44, 4 }, -- Devouring Plague 4
    { 10915, 44, 5 }, -- Flash Heal 5
    { 27799, 44, 4, 1 }, -- Holy Nova 4
    { 27803, 44, 4, 1 }, -- Holy Nova 4
    { 10911, 44, 2 }, -- Mind Control 2
    { 17313, 44, 4, 1 }, -- Mind Flay 4
    { 10909, 44, 2 }, -- Mind Vision 2
    { 10927, 44, 7 }, -- Renew 7
    { 19310, 44, 4, 0, 128 }, -- Shadowguard 4
    { 28380, 44, 4, 0, 128 }, -- Shadowguard 4
    { 10963, 46, 2 }, -- Greater Heal 2
    { 10945, 46, 7 }, -- Mind Blast 7
    { 10881, 46, 4 }, -- Resurrection 4
    { 10933, 46, 7 }, -- Smite 7
    { 15266, 48, 6 }, -- Holy Fire 6
    { 10875, 48, 4 }, -- Mana Burn 4
    { 10937, 48, 5 }, -- Power Word: Fortitude 5
    { 10899, 48, 8 }, -- Power Word: Shield 8
    { 21562, 48, 1 }, -- Prayer of Fortitude 1
    { 1309635, 48, 3 }, -- Shadow Word: Death 3
    { 1277334, 50, 4, 0, 4 }, -- Chastise 4
    { 1277639, 50, 4, 0, 64 }, -- Contingency Plan 4
    { 1277327, 50, 4, 0, 16 }, -- Dark Sacrifice 4
    { 19242, 50, 6, 0, 4 }, -- Desperate Prayer 6
    { 1277377, 50, 6, 0, 1 }, -- Divine Grace 6
    { 14819, 50, 3, 1 }, -- Divine Spirit 3
    { 10941, 50, 5 }, -- Fade 5
    { 19274, 50, 4, 0, 1 }, -- Feedback 4
    { 10916, 50, 6 }, -- Flash Heal 6
    { 19284, 50, 5, 0, 128 }, -- Hex of Weakness 5
    { 10951, 50, 5 }, -- Inner Fire 5
    { 27870, 50, 2, 1 }, -- Lightwell 2
    { 27873, 50, 2 }, -- Lightwell Renew 2
    { 1240721, 50, 3, 1 }, -- Penance 3
    { 10960, 50, 3 }, -- Prayer of Healing 3
    { 1240826, 50, 2, 1 }, -- Prayer of Mending 2
    { 10928, 50, 8 }, -- Renew 8
    { 10893, 50, 7 }, -- Shadow Word: Pain 7
    { 19304, 50, 6, 0, 8 }, -- Starshards 6
    { 19265, 50, 5, 0, 16 }, -- Touch of Weakness 5
    { 19253, 50, 5, 0, 16 }, -- Touch of Weakness 5
    { 19279, 52, 5 }, -- Devouring Plague 5
    { 10964, 52, 3 }, -- Greater Heal 3
    { 27800, 52, 5, 1 }, -- Holy Nova 5
    { 27804, 52, 5, 1 }, -- Holy Nova 5
    { 10946, 52, 8 }, -- Mind Blast 8
    { 17314, 52, 5, 1 }, -- Mind Flay 5
    { 10953, 52, 3 }, -- Mind Soothe 3
    { 19311, 52, 5, 0, 128 }, -- Shadowguard 5
    { 28381, 52, 5, 0, 128 }, -- Shadowguard 5
    { 15267, 54, 7 }, -- Holy Fire 7
    { 10900, 54, 9 }, -- Power Word: Shield 9
    { 10934, 54, 8 }, -- Smite 8
    { 10917, 56, 7 }, -- Flash Heal 7
    { 10876, 56, 5 }, -- Mana Burn 5
    { 27683, 56, 0 }, -- Prayer of Shadow Protection
    { 10890, 56, 4 }, -- Psychic Scream 4
    { 10929, 56, 9 }, -- Renew 9
    { 10958, 56, 3 }, -- Shadow Protection 3
    { 1309636, 56, 4 }, -- Shadow Word: Death 4
    { 19243, 58, 7, 0, 4 }, -- Desperate Prayer 7
    { 1277378, 58, 7, 0, 1 }, -- Divine Grace 7
    { 10965, 58, 4 }, -- Greater Heal 4
    { 10947, 58, 9 }, -- Mind Blast 9
    { 10912, 58, 3 }, -- Mind Control 3
    { 20770, 58, 5 }, -- Resurrection 5
    { 10894, 58, 8 }, -- Shadow Word: Pain 8
    { 19305, 58, 7, 0, 8 }, -- Starshards 7
    { 1277335, 60, 5, 0, 4 }, -- Chastise 5
    { 1277640, 60, 5, 0, 64 }, -- Contingency Plan 5
    { 1277328, 60, 5, 0, 16 }, -- Dark Sacrifice 5
    { 19280, 60, 6 }, -- Devouring Plague 6
    { 27841, 60, 4, 1 }, -- Divine Spirit 4
    { 10942, 60, 6 }, -- Fade 6
    { 19275, 60, 5, 0, 1 }, -- Feedback 5
    { 25314, 60, 5 }, -- Greater Heal 5
    { 19285, 60, 6, 0, 128 }, -- Hex of Weakness 6
    { 15261, 60, 8 }, -- Holy Fire 8
    { 27801, 60, 6, 1 }, -- Holy Nova 6
    { 27805, 60, 6, 1 }, -- Holy Nova 6
    { 10952, 60, 6 }, -- Inner Fire 6
    { 27871, 60, 3, 1 }, -- Lightwell 3
    { 27874, 60, 3 }, -- Lightwell Renew 3
    { 18807, 60, 6, 1 }, -- Mind Flay 6
    { 1316995, 60, 4, 1 }, -- Penance 4
    { 10938, 60, 6 }, -- Power Word: Fortitude 6
    { 10901, 60, 10 }, -- Power Word: Shield 10
    { 21564, 60, 2 }, -- Prayer of Fortitude 2
    { 10961, 60, 4 }, -- Prayer of Healing 4
    { 25316, 60, 5 }, -- Prayer of Healing 5
    { 1240827, 60, 3, 1 }, -- Prayer of Mending 3
    { 27681, 60, 1 }, -- Prayer of Spirit 1
    { 25315, 60, 10 }, -- Renew 10
    { 10955, 60, 3 }, -- Shackle Undead 3
    { 19312, 60, 6, 0, 128 }, -- Shadowguard 6
    { 28382, 60, 6, 0, 128 }, -- Shadowguard 6
    { 19266, 60, 6, 0, 16 }, -- Touch of Weakness 6
    { 19254, 60, 6, 0, 16 }, -- Touch of Weakness 6
  },
  ROGUE = {
    { 53, 4, 1 }, -- Backstab 1
    { 921, 4, 0 }, -- Pick Pocket
    { 1776, 6, 1 }, -- Gouge 1
    { 1757, 6, 2 }, -- Sinister Strike 2
    { 5277, 8, 0 }, -- Evasion
    { 6760, 8, 2 }, -- Eviscerate 2
    { 6770, 10, 1 }, -- Sap 1
    { 5171, 10, 1 }, -- Slice and Dice 1
    { 2983, 10, 1 }, -- Sprint 1
    { 2589, 12, 2 }, -- Backstab 2
    { 1766, 12, 1 }, -- Kick 1
    { 8647, 14, 1 }, -- Expose Armor 1
    { 703, 14, 1 }, -- Garrote 1
    { 1758, 14, 3 }, -- Sinister Strike 3
    { 6761, 16, 3 }, -- Eviscerate 3
    { 1966, 16, 1 }, -- Feint 1
    { 8676, 18, 1 }, -- Ambush 1
    { 1777, 18, 2 }, -- Gouge 2
    { 1328825, 18, 0 }, -- Poised
    { 2590, 20, 3 }, -- Backstab 3
    { 1943, 20, 1 }, -- Rupture 1
    { 1785, 20, 2 }, -- Stealth 2
    { 1725, 22, 0 }, -- Distract
    { 8631, 22, 2 }, -- Garrote 2
    { 1759, 22, 4 }, -- Sinister Strike 4
    { 1856, 22, 1 }, -- Vanish 1
    { 2836, 24, 0 }, -- Detect Traps
    { 6762, 24, 4 }, -- Eviscerate 4
    { 1329283, 24, 1 }, -- Shank 1
    { 8724, 26, 2 }, -- Ambush 2
    { 1833, 26, 0 }, -- Cheap Shot
    { 8649, 26, 2 }, -- Expose Armor 2
    { 1767, 26, 2 }, -- Kick 2
    { 2591, 28, 4 }, -- Backstab 4
    { 6768, 28, 2 }, -- Feint 2
    { 8639, 28, 2 }, -- Rupture 2
    { 2070, 28, 2 }, -- Sap 2
    { 1842, 30, 0 }, -- Disarm Trap
    { 8632, 30, 3 }, -- Garrote 3
    { 408, 30, 1 }, -- Kidney Shot 1
    { 1760, 30, 5 }, -- Sinister Strike 5
    { 8623, 32, 5 }, -- Eviscerate 5
    { 8629, 32, 3 }, -- Gouge 3
    { 8725, 34, 3 }, -- Ambush 3
    { 2094, 34, 0 }, -- Blind
    { 8696, 34, 2 }, -- Sprint 2
    { 8721, 36, 5 }, -- Backstab 5
    { 8650, 36, 3 }, -- Expose Armor 3
    { 8640, 36, 3 }, -- Rupture 3
    { 8633, 38, 4 }, -- Garrote 4
    { 8621, 38, 6 }, -- Sinister Strike 6
    { 8624, 40, 6 }, -- Eviscerate 6
    { 8637, 40, 3 }, -- Feint 3
    { 1860, 40, 0 }, -- Safe Fall
    { 1786, 40, 3 }, -- Stealth 3
    { 11267, 42, 4 }, -- Ambush 4
    { 1768, 42, 3 }, -- Kick 3
    { 6774, 42, 2 }, -- Slice and Dice 2
    { 1857, 42, 2 }, -- Vanish 2
    { 11279, 44, 6 }, -- Backstab 6
    { 11273, 44, 4 }, -- Rupture 4
    { 1329549, 44, 2 }, -- Shank 2
    { 11197, 46, 4 }, -- Expose Armor 4
    { 11289, 46, 5 }, -- Garrote 5
    { 11285, 46, 4 }, -- Gouge 4
    { 11293, 46, 7 }, -- Sinister Strike 7
    { 1325756, 48, 2, 1 }, -- Death Mark 2
    { 11299, 48, 7 }, -- Eviscerate 7
    { 11297, 48, 3 }, -- Sap 3
    { 11268, 50, 5 }, -- Ambush 5
    { 8643, 50, 2 }, -- Kidney Shot 2
    { 1241582, 50, 2, 1 }, -- Mutilate 2
    { 11280, 52, 7 }, -- Backstab 7
    { 11303, 52, 4 }, -- Feint 4
    { 11274, 52, 5 }, -- Rupture 5
    { 11290, 54, 6 }, -- Garrote 6
    { 11294, 54, 8 }, -- Sinister Strike 8
    { 1325757, 56, 3, 1 }, -- Death Mark 3
    { 11300, 56, 8 }, -- Eviscerate 8
    { 11198, 56, 5 }, -- Expose Armor 5
    { 11269, 58, 6 }, -- Ambush 6
    { 1769, 58, 4 }, -- Kick 4
    { 11305, 58, 3 }, -- Sprint 3
    { 11281, 60, 8 }, -- Backstab 8
    { 25300, 60, 9 }, -- Backstab 9
    { 1325758, 60, 4, 1 }, -- Death Mark 4
    { 31016, 60, 9 }, -- Eviscerate 9
    { 25302, 60, 5 }, -- Feint 5
    { 11286, 60, 5 }, -- Gouge 5
    { 1241584, 60, 3, 1 }, -- Mutilate 3
    { 11275, 60, 6 }, -- Rupture 6
    { 1787, 60, 4 }, -- Stealth 4
  },
  SHAMAN = {
    { 8042, 4, 1 }, -- Earth Shock 1
    { 8071, 4, 1 }, -- Stoneskin Totem 1
    { 2484, 6, 0 }, -- Earthbind Totem
    { 332, 6, 2 }, -- Healing Wave 2
    { 8044, 8, 2 }, -- Earth Shock 2
    { 529, 8, 2 }, -- Lightning Bolt 2
    { 324, 8, 1 }, -- Lightning Shield 1
    { 26364, 8, 1 }, -- Lightning Shield 1
    { 8018, 8, 2 }, -- Rockbiter Weapon 2
    { 5730, 8, 1 }, -- Stoneclaw Totem 1
    { 8050, 10, 1 }, -- Flame Shock 1
    { 8024, 10, 1 }, -- Flametongue Weapon 1
    { 3599, 10, 1 }, -- Searing Totem 1
    { 8075, 10, 1 }, -- Strength of Earth Totem 1
    { 2008, 12, 1 }, -- Ancestral Spirit 1
    { 408341, 12, 1 }, -- Fire Nova 1
    { 547, 12, 3 }, -- Healing Wave 3
    { 370, 12, 1 }, -- Purge 1
    { 8045, 14, 3 }, -- Earth Shock 3
    { 548, 14, 3 }, -- Lightning Bolt 3
    { 8154, 14, 2 }, -- Stoneskin Totem 2
    { 526, 16, 0 }, -- Cure Poison
    { 325, 16, 2 }, -- Lightning Shield 2
    { 26365, 16, 2 }, -- Lightning Shield 2
    { 8019, 16, 3 }, -- Rockbiter Weapon 3
    { 8052, 18, 2 }, -- Flame Shock 2
    { 8027, 18, 2 }, -- Flametongue Weapon 2
    { 913, 18, 4 }, -- Healing Wave 4
    { 6390, 18, 2 }, -- Stoneclaw Totem 2
    { 8143, 18, 0 }, -- Tremor Totem
    { 66842, 20, 0 }, -- Call of the Elements
    { 8056, 20, 1 }, -- Frost Shock 1
    { 8033, 20, 1 }, -- Frostbrand Weapon 1
    { 2645, 20, 0 }, -- Ghost Wolf
    { 5394, 20, 1 }, -- Healing Stream Totem 1
    { 8004, 20, 1 }, -- Lesser Healing Wave 1
    { 915, 20, 4 }, -- Lightning Bolt 4
    { 6363, 20, 2 }, -- Searing Totem 2
    { 36936, 20, 0 }, -- Totemic Recall
    { 2870, 22, 0 }, -- Cure Disease
    { 408342, 22, 2 }, -- Fire Nova 2
    { 8166, 22, 0 }, -- Poison Cleansing Totem
    { 437009, 22, 0 }, -- Totemic Call
    { 131, 22, 0 }, -- Water Breathing
    { 20609, 24, 2 }, -- Ancestral Spirit 2
    { 8046, 24, 4 }, -- Earth Shock 4
    { 8181, 24, 1 }, -- Frost Resistance Totem 1
    { 939, 24, 5 }, -- Healing Wave 5
    { 905, 24, 3 }, -- Lightning Shield 3
    { 26366, 24, 3 }, -- Lightning Shield 3
    { 10399, 24, 4 }, -- Rockbiter Weapon 4
    { 8155, 24, 3 }, -- Stoneskin Totem 3
    { 8160, 24, 2 }, -- Strength of Earth Totem 2
    { 6196, 26, 0 }, -- Far Sight
    { 8030, 26, 3 }, -- Flametongue Weapon 3
    { 943, 26, 5 }, -- Lightning Bolt 5
    { 8190, 26, 1 }, -- Magma Totem 1
    { 5675, 26, 1 }, -- Mana Spring Totem 1
    { 8184, 28, 1 }, -- Fire Resistance Totem 1
    { 8053, 28, 3 }, -- Flame Shock 3
    { 8227, 28, 1 }, -- Flametongue Totem 1
    { 8038, 28, 2 }, -- Frostbrand Weapon 2
    { 8008, 28, 2 }, -- Lesser Healing Wave 2
    { 6391, 28, 3 }, -- Stoneclaw Totem 3
    { 546, 28, 0 }, -- Water Walking
    { 556, 30, 0 }, -- Astral Recall
    { 66843, 30, 0 }, -- Call of the Ancestors
    { 8177, 30, 0 }, -- Grounding Totem
    { 6375, 30, 2 }, -- Healing Stream Totem 2
    { 10595, 30, 1 }, -- Nature Resistance Totem 1
    { 20608, 30, 0 }, -- Reincarnation
    { 21169, 30, 0 }, -- Reincarnation
    { 6364, 30, 3 }, -- Searing Totem 3
    { 8232, 30, 1 }, -- Windfury Weapon 1
    { 421, 32, 1 }, -- Chain Lightning 1
    { 408343, 32, 3 }, -- Fire Nova 3
    { 959, 32, 6 }, -- Healing Wave 6
    { 6041, 32, 6 }, -- Lightning Bolt 6
    { 945, 32, 4 }, -- Lightning Shield 4
    { 26367, 32, 4 }, -- Lightning Shield 4
    { 8012, 32, 2 }, -- Purge 2
    { 8512, 32, 1 }, -- Windfury Totem 1
    { 8058, 34, 2 }, -- Frost Shock 2
    { 16314, 34, 5 }, -- Rockbiter Weapon 5
    { 6495, 34, 0 }, -- Sentry Totem
    { 10406, 34, 4 }, -- Stoneskin Totem 4
    { 20610, 36, 3 }, -- Ancestral Spirit 3
    { 10412, 36, 5 }, -- Earth Shock 5
    { 16339, 36, 4 }, -- Flametongue Weapon 4
    { 8010, 36, 3 }, -- Lesser Healing Wave 3
    { 10585, 36, 2 }, -- Magma Totem 2
    { 10495, 36, 2 }, -- Mana Spring Totem 2
    { 15107, 36, 1 }, -- Windwall Totem 1
    { 8170, 38, 0 }, -- Disease Cleansing Totem
    { 8249, 38, 2 }, -- Flametongue Totem 2
    { 10478, 38, 2 }, -- Frost Resistance Totem 2
    { 10456, 38, 3 }, -- Frostbrand Weapon 3
    { 10391, 38, 7 }, -- Lightning Bolt 7
    { 17354, 38, 2, 1 }, -- Mana Tide Totem 2
    { 6392, 38, 4 }, -- Stoneclaw Totem 4
    { 8161, 38, 3 }, -- Strength of Earth Totem 3
    { 66844, 40, 0 }, -- Call of the Spirits
    { 1064, 40, 1 }, -- Chain Heal 1
    { 930, 40, 2 }, -- Chain Lightning 2
    { 10447, 40, 4 }, -- Flame Shock 4
    { 6377, 40, 3 }, -- Healing Stream Totem 3
    { 8005, 40, 7 }, -- Healing Wave 7
    { 8134, 40, 5 }, -- Lightning Shield 5
    { 26369, 40, 5 }, -- Lightning Shield 5
    { 6365, 40, 4 }, -- Searing Totem 4
    { 8235, 40, 2 }, -- Windfury Weapon 2
    { 408344, 42, 4 }, -- Fire Nova 4
    { 10537, 42, 2 }, -- Fire Resistance Totem 2
    { 8835, 42, 1 }, -- Grace of Air Totem 1
    { 10613, 42, 2 }, -- Windfury Totem 2
    { 10466, 44, 4 }, -- Lesser Healing Wave 4
    { 10392, 44, 8 }, -- Lightning Bolt 8
    { 10600, 44, 2 }, -- Nature Resistance Totem 2
    { 16315, 44, 6 }, -- Rockbiter Weapon 6
    { 10407, 44, 5 }, -- Stoneskin Totem 5
    { 10622, 46, 2 }, -- Chain Heal 2
    { 16341, 46, 5 }, -- Flametongue Weapon 5
    { 10472, 46, 3 }, -- Frost Shock 3
    { 10586, 46, 3 }, -- Magma Totem 3
    { 10496, 46, 3 }, -- Mana Spring Totem 3
    { 15111, 46, 2 }, -- Windwall Totem 2
    { 20776, 48, 4 }, -- Ancestral Spirit 4
    { 2860, 48, 3 }, -- Chain Lightning 3
    { 10413, 48, 6 }, -- Earth Shock 6
    { 10526, 48, 3 }, -- Flametongue Totem 3
    { 16355, 48, 4 }, -- Frostbrand Weapon 4
    { 10395, 48, 8 }, -- Healing Wave 8
    { 10431, 48, 6 }, -- Lightning Shield 6
    { 26370, 48, 6 }, -- Lightning Shield 6
    { 17359, 48, 3, 1 }, -- Mana Tide Totem 3
    { 10427, 48, 5 }, -- Stoneclaw Totem 5
    { 10462, 50, 4 }, -- Healing Stream Totem 4
    { 15207, 50, 9 }, -- Lightning Bolt 9
    { 1239242, 50, 2, 1 }, -- Riptide 2
    { 10437, 50, 5 }, -- Searing Totem 5
    { 10486, 50, 3 }, -- Windfury Weapon 3
    { 408345, 52, 5 }, -- Fire Nova 5
    { 10448, 52, 5 }, -- Flame Shock 5
    { 10467, 52, 5 }, -- Lesser Healing Wave 5
    { 10442, 52, 4 }, -- Strength of Earth Totem 4
    { 10614, 52, 3 }, -- Windfury Totem 3
    { 10623, 54, 3 }, -- Chain Heal 3
    { 10479, 54, 3 }, -- Frost Resistance Totem 3
    { 16316, 54, 7 }, -- Rockbiter Weapon 7
    { 10408, 54, 6 }, -- Stoneskin Totem 6
    { 10605, 56, 4 }, -- Chain Lightning 4
    { 16342, 56, 6 }, -- Flametongue Weapon 6
    { 10627, 56, 2 }, -- Grace of Air Totem 2
    { 10396, 56, 9 }, -- Healing Wave 9
    { 15208, 56, 10 }, -- Lightning Bolt 10
    { 10432, 56, 7 }, -- Lightning Shield 7
    { 26363, 56, 7 }, -- Lightning Shield 7
    { 10587, 56, 4 }, -- Magma Totem 4
    { 10497, 56, 4 }, -- Mana Spring Totem 4
    { 15112, 56, 3 }, -- Windwall Totem 3
    { 10538, 58, 3 }, -- Fire Resistance Totem 3
    { 16387, 58, 4 }, -- Flametongue Totem 4
    { 10473, 58, 4 }, -- Frost Shock 4
    { 16356, 58, 5 }, -- Frostbrand Weapon 5
    { 1325256, 58, 4, 1 }, -- Mana Tide Totem 4
    { 10428, 58, 6 }, -- Stoneclaw Totem 6
    { 20777, 60, 5 }, -- Ancestral Spirit 5
    { 10414, 60, 7 }, -- Earth Shock 7
    { 29228, 60, 6 }, -- Flame Shock 6
    { 25359, 60, 3 }, -- Grace of Air Totem 3
    { 10463, 60, 5 }, -- Healing Stream Totem 5
    { 25357, 60, 10 }, -- Healing Wave 10
    { 10468, 60, 6 }, -- Lesser Healing Wave 6
    { 10601, 60, 3 }, -- Nature Resistance Totem 3
    { 1239243, 60, 3, 1 }, -- Riptide 3
    { 10438, 60, 6 }, -- Searing Totem 6
    { 25361, 60, 5 }, -- Strength of Earth Totem 5
    { 16362, 60, 4 }, -- Windfury Weapon 4
  },
  WARLOCK = {
    { 172, 4, 1 }, -- Corruption 1
    { 702, 4, 1 }, -- Curse of Weakness 1
    { 1454, 6, 1 }, -- Life Tap 1
    { 695, 6, 2 }, -- Shadow Bolt 2
    { 980, 8, 1 }, -- Bane of Agony 1
    { 5782, 8, 1 }, -- Fear 1
    { 6201, 10, 1 }, -- Create Healthstone 1
    { 696, 10, 2 }, -- Demon Skin 2
    { 1120, 10, 1 }, -- Drain Soul 1
    { 707, 10, 2 }, -- Immolate 2
    { 697, 10, 0 }, -- Summon Voidwalker
    { 1108, 12, 2 }, -- Curse of Weakness 2
    { 755, 12, 1 }, -- Health Funnel 1
    { 705, 12, 3 }, -- Shadow Bolt 3
    { 6222, 14, 2 }, -- Corruption 2
    { 704, 14, 1 }, -- Curse of Recklessness 1
    { 689, 14, 1 }, -- Drain Life 1
    { 1455, 16, 2 }, -- Life Tap 2
    { 5697, 16, 0 }, -- Unending Breath
    { 1014, 18, 2 }, -- Bane of Agony 2
    { 693, 18, 1 }, -- Create Soulstone 1
    { 5676, 18, 1 }, -- Searing Pain 1
    { 706, 20, 1 }, -- Demon Armor 1
    { 3698, 20, 2 }, -- Health Funnel 2
    { 1094, 20, 3 }, -- Immolate 3
    { 5740, 20, 1 }, -- Rain of Fire 1
    { 698, 20, 0 }, -- Ritual of Summoning
    { 1088, 20, 4 }, -- Shadow Bolt 4
    { 713, 20, 0 }, -- Summon Incubus
    { 712, 20, 0 }, -- Summon Succubus
    { 6202, 22, 2 }, -- Create Healthstone 2
    { 6205, 22, 3 }, -- Curse of Weakness 3
    { 699, 22, 2 }, -- Drain Life 2
    { 126, 22, 0 }, -- Eye of Kilrogg
    { 6223, 24, 3 }, -- Corruption 3
    { 5138, 24, 1 }, -- Drain Mana 1
    { 8288, 24, 2 }, -- Drain Soul 2
    { 5500, 24, 0 }, -- Sense Demons
    { 18867, 24, 2, 1 }, -- Shadowburn 2
    { 1714, 26, 1 }, -- Curse of Tongues 1
    { 132, 26, 1 }, -- Detect Invisibility 1
    { 1456, 26, 3 }, -- Life Tap 3
    { 17919, 26, 2 }, -- Searing Pain 2
    { 6217, 28, 3 }, -- Bane of Agony 3
    { 710, 28, 1 }, -- Banish 1
    { 6366, 28, 1 }, -- Create Firestone 1
    { 7658, 28, 2 }, -- Curse of Recklessness 2
    { 3699, 28, 3 }, -- Health Funnel 3
    { 1106, 28, 5 }, -- Shadow Bolt 5
    { 20752, 30, 2 }, -- Create Soulstone 2
    { 1311676, 30, 2, 1 }, -- Curse of the Elements 2
    { 1086, 30, 2 }, -- Demon Armor 2
    { 709, 30, 3 }, -- Drain Life 3
    { 1949, 30, 1 }, -- Hellfire 1
    { 2941, 30, 4 }, -- Immolate 4
    { 1098, 30, 1 }, -- Subjugate Demon 1
    { 691, 30, 0 }, -- Summon Felhunter
    { 1293818, 32, 2, 1 }, -- Conflagrate 2
    { 7646, 32, 4 }, -- Curse of Weakness 4
    { 6213, 32, 2 }, -- Fear 2
    { 6229, 32, 1 }, -- Shadow Ward 1
    { 18868, 32, 3, 1 }, -- Shadowburn 3
    { 7648, 34, 4 }, -- Corruption 4
    { 5699, 34, 3 }, -- Create Healthstone 3
    { 6226, 34, 2 }, -- Drain Mana 2
    { 6219, 34, 2 }, -- Rain of Fire 2
    { 17920, 34, 3 }, -- Searing Pain 3
    { 18093, 35, 0, 1 }, -- Pyroclasm
    { 17951, 36, 2 }, -- Create Firestone 2
    { 2362, 36, 1 }, -- Create Spellstone 1
    { 3700, 36, 4 }, -- Health Funnel 4
    { 11687, 36, 4 }, -- Life Tap 4
    { 7641, 36, 6 }, -- Shadow Bolt 6
    { 11711, 38, 4 }, -- Bane of Agony 4
    { 2970, 38, 2 }, -- Detect Invisibility 2
    { 7651, 38, 4 }, -- Drain Life 4
    { 8289, 38, 3 }, -- Drain Soul 3
    { 18879, 38, 2, 1 }, -- Siphon Life 2
    { 20755, 40, 3 }, -- Create Soulstone 3
    { 1311677, 40, 3, 1 }, -- Curse of the Elements 3
    { 11733, 40, 3 }, -- Demon Armor 3
    { 5484, 40, 1 }, -- Howl of Terror 1
    { 11665, 40, 5 }, -- Immolate 5
    { 18869, 40, 4, 1 }, -- Shadowburn 4
    { 7659, 42, 3 }, -- Curse of Recklessness 3
    { 11707, 42, 5 }, -- Curse of Weakness 5
    { 6789, 42, 1 }, -- Death Coil 1
    { 11683, 42, 2 }, -- Hellfire 2
    { 17921, 42, 4 }, -- Searing Pain 4
    { 11739, 42, 2 }, -- Shadow Ward 2
    { 11671, 44, 5 }, -- Corruption 5
    { 11703, 44, 3 }, -- Drain Mana 3
    { 11693, 44, 5 }, -- Health Funnel 5
    { 11659, 44, 7 }, -- Shadow Bolt 7
    { 11725, 44, 2 }, -- Subjugate Demon 2
    { 17952, 46, 3 }, -- Create Firestone 3
    { 11729, 46, 4 }, -- Create Healthstone 4
    { 11699, 46, 5 }, -- Drain Life 5
    { 11688, 46, 5 }, -- Life Tap 5
    { 11677, 46, 3 }, -- Rain of Fire 3
    { 11712, 48, 5 }, -- Bane of Agony 5
    { 18647, 48, 2 }, -- Banish 2
    { 18930, 48, 4, 1 }, -- Conflagrate 4
    { 17727, 48, 2 }, -- Create Spellstone 2
    { 18870, 48, 5, 1 }, -- Shadowburn 5
    { 18880, 48, 3, 1 }, -- Siphon Life 3
    { 6353, 48, 1 }, -- Soul Fire 1
    { 20756, 50, 4 }, -- Create Soulstone 4
    { 11719, 50, 2 }, -- Curse of Tongues 2
    { 1311680, 50, 4, 1 }, -- Curse of the Elements 4
    { 17925, 50, 2 }, -- Death Coil 2
    { 11734, 50, 4 }, -- Demon Armor 4
    { 11743, 50, 3 }, -- Detect Invisibility 3
    { 11667, 50, 6 }, -- Immolate 6
    { 1293812, 50, 2, 1 }, -- Incinerate 2
    { 1122, 50, 0 }, -- Inferno
    { 17922, 50, 5 }, -- Searing Pain 5
    { 11708, 52, 6 }, -- Curse of Weakness 6
    { 11675, 52, 4 }, -- Drain Soul 4
    { 11694, 52, 6 }, -- Health Funnel 6
    { 11660, 52, 8 }, -- Shadow Bolt 8
    { 11740, 52, 3 }, -- Shadow Ward 3
    { 18931, 54, 5, 1 }, -- Conflagrate 5
    { 11672, 54, 6 }, -- Corruption 6
    { 11700, 54, 6 }, -- Drain Life 6
    { 11704, 54, 4 }, -- Drain Mana 4
    { 11684, 54, 3 }, -- Hellfire 3
    { 17928, 54, 2 }, -- Howl of Terror 2
    { 17953, 56, 4 }, -- Create Firestone 4
    { 11717, 56, 4 }, -- Curse of Recklessness 4
    { 6215, 56, 3 }, -- Fear 3
    { 11689, 56, 6 }, -- Life Tap 6
    { 18871, 56, 6, 1 }, -- Shadowburn 6
    { 17924, 56, 2 }, -- Soul Fire 2
    { 11713, 58, 6 }, -- Bane of Agony 6
    { 11730, 58, 5 }, -- Create Healthstone 5
    { 17926, 58, 3 }, -- Death Coil 3
    { 11678, 58, 4 }, -- Rain of Fire 4
    { 17923, 58, 6 }, -- Searing Pain 6
    { 18881, 58, 4, 1 }, -- Siphon Life 4
    { 11726, 58, 3 }, -- Subjugate Demon 3
    { 603, 60, 0 }, -- Bane of Doom
    { 18662, 60, 0 }, -- Bane of Doom Effect
    { 18932, 60, 6, 1 }, -- Conflagrate 6
    { 25311, 60, 7 }, -- Corruption 7
    { 20757, 60, 5 }, -- Create Soulstone 5
    { 17728, 60, 3 }, -- Create Spellstone 3
    { 11735, 60, 5 }, -- Demon Armor 5
    { 11695, 60, 7 }, -- Health Funnel 7
    { 11668, 60, 7 }, -- Immolate 7
    { 25309, 60, 8 }, -- Immolate 8
    { 1293813, 60, 3, 1 }, -- Incinerate 3
    { 437169, 60, 0 }, -- Portal of Summoning
    { 18540, 60, 0 }, -- Ritual of Doom
    { 11661, 60, 9 }, -- Shadow Bolt 9
    { 25307, 60, 10 }, -- Shadow Bolt 10
    { 28610, 60, 4 }, -- Shadow Ward 4
  },
  WARRIOR = {
    { 100, 4, 1 }, -- Charge 1
    { 772, 4, 1 }, -- Rend 1
    { 6343, 6, 1 }, -- Thunder Clap 1
    { 1715, 8, 1 }, -- Hamstring 1
    { 284, 8, 2 }, -- Heroic Strike 2
    { 2687, 10, 0 }, -- Bloodrage
    { 71, 10, 0 }, -- Defensive Stance
    { 7376, 10, 0 }, -- Defensive Stance Passive
    { 6546, 10, 2 }, -- Rend 2
    { 7386, 10, 1 }, -- Sunder Armor 1
    { 355, 10, 0 }, -- Taunt
    { 5242, 12, 2 }, -- Battle Shout 2
    { 7384, 12, 1 }, -- Overpower 1
    { 72, 12, 1 }, -- Shield Bash 1
    { 1160, 14, 1 }, -- Demoralizing Shout 1
    { 6572, 14, 1 }, -- Revenge 1
    { 1310185, 14, 0 }, -- Tactical Mastery
    { 285, 16, 3 }, -- Heroic Strike 3
    { 694, 16, 1 }, -- Mocking Blow 1
    { 2565, 16, 0 }, -- Shield Block
    { 676, 18, 0 }, -- Disarm
    { 8198, 18, 2 }, -- Thunder Clap 2
    { 845, 20, 1 }, -- Cleave 1
    { 6547, 20, 3 }, -- Rend 3
    { 20230, 20, 0 }, -- Retaliation
    { 1240193, 20, 1 }, -- Slam 1
    { 6192, 22, 3 }, -- Battle Shout 3
    { 5246, 22, 0 }, -- Intimidating Shout
    { 7405, 22, 2 }, -- Sunder Armor 2
    { 6190, 24, 2 }, -- Demoralizing Shout 2
    { 5308, 24, 1 }, -- Execute 1
    { 1608, 24, 4 }, -- Heroic Strike 4
    { 6574, 24, 2 }, -- Revenge 2
    { 1161, 26, 0 }, -- Challenging Shout
    { 6178, 26, 2 }, -- Charge 2
    { 7400, 26, 2 }, -- Mocking Blow 2
    { 7887, 28, 2 }, -- Overpower 2
    { 871, 28, 0 }, -- Shield Wall
    { 8204, 28, 3 }, -- Thunder Clap 3
    { 18499, 30, 0 }, -- Berserker Rage
    { 2458, 30, 0 }, -- Berserker Stance
    { 7381, 30, 0 }, -- Berserker Stance Passive
    { 7369, 30, 2 }, -- Cleave 2
    { 20252, 30, 1 }, -- Intercept 1
    { 6548, 30, 4 }, -- Rend 4
    { 1464, 30, 2 }, -- Slam 2
    { 11549, 32, 4 }, -- Battle Shout 4
    { 20658, 32, 2 }, -- Execute 2
    { 7372, 32, 2 }, -- Hamstring 2
    { 11564, 32, 5 }, -- Heroic Strike 5
    { 1671, 32, 2 }, -- Shield Bash 2
    { 11554, 34, 3 }, -- Demoralizing Shout 3
    { 7379, 34, 3 }, -- Revenge 3
    { 8380, 34, 3 }, -- Sunder Armor 3
    { 7402, 36, 3 }, -- Mocking Blow 3
    { 1680, 36, 0 }, -- Whirlwind
    { 6552, 38, 1 }, -- Pummel 1
    { 8820, 38, 3 }, -- Slam 3
    { 8205, 38, 4 }, -- Thunder Clap 4
    { 11608, 40, 3 }, -- Cleave 3
    { 20660, 40, 3 }, -- Execute 3
    { 11565, 40, 6 }, -- Heroic Strike 6
    { 11572, 40, 5 }, -- Rend 5
    { 11550, 42, 5 }, -- Battle Shout 5
    { 20616, 42, 2 }, -- Intercept 2
    { 11555, 44, 4 }, -- Demoralizing Shout 4
    { 11584, 44, 3 }, -- Overpower 3
    { 11600, 44, 4 }, -- Revenge 4
    { 11578, 46, 3 }, -- Charge 3
    { 20559, 46, 4 }, -- Mocking Blow 4
    { 11604, 46, 4 }, -- Slam 4
    { 11596, 46, 4 }, -- Sunder Armor 4
    { 23892, 48, 2, 1 }, -- Bloodthirst 2
    { 20661, 48, 4 }, -- Execute 4
    { 11566, 48, 7 }, -- Heroic Strike 7
    { 21551, 48, 2, 1 }, -- Mortal Strike 2
    { 23923, 48, 2, 1 }, -- Shield Slam 2
    { 11580, 48, 5 }, -- Thunder Clap 5
    { 11609, 50, 4 }, -- Cleave 4
    { 1719, 50, 0 }, -- Recklessness
    { 11573, 50, 6 }, -- Rend 6
    { 11551, 52, 6 }, -- Battle Shout 6
    { 20617, 52, 3 }, -- Intercept 3
    { 1672, 52, 3 }, -- Shield Bash 3
    { 23893, 54, 3, 1 }, -- Bloodthirst 3
    { 11556, 54, 5 }, -- Demoralizing Shout 5
    { 7373, 54, 3 }, -- Hamstring 3
    { 21552, 54, 3, 1 }, -- Mortal Strike 3
    { 11601, 54, 5 }, -- Revenge 5
    { 23924, 54, 3, 1 }, -- Shield Slam 3
    { 11605, 54, 5 }, -- Slam 5
    { 20662, 56, 5 }, -- Execute 5
    { 11567, 56, 8 }, -- Heroic Strike 8
    { 20560, 56, 5 }, -- Mocking Blow 5
    { 6554, 58, 2 }, -- Pummel 2
    { 11597, 58, 5 }, -- Sunder Armor 5
    { 11581, 58, 6 }, -- Thunder Clap 6
    { 25289, 60, 7 }, -- Battle Shout 7
    { 23894, 60, 4, 1 }, -- Bloodthirst 4
    { 20569, 60, 5 }, -- Cleave 5
    { 25286, 60, 9 }, -- Heroic Strike 9
    { 21553, 60, 4, 1 }, -- Mortal Strike 4
    { 11585, 60, 4 }, -- Overpower 4
    { 11574, 60, 7 }, -- Rend 7
    { 25288, 60, 6 }, -- Revenge 6
    { 23925, 60, 4, 1 }, -- Shield Slam 4
  },
}
