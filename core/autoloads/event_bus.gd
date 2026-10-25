extends Node

# Combat and entity events
signal entity_damaged(entity: Node2D, amount: float, is_crit: bool)
signal enemy_purified(enemy_data: Resource, position: Vector2, exp_reward: int)
signal boss_defeated(boss_id: String)

# Player and progression events
signal player_hp_changed(current_hp: float, max_hp: float)
signal player_mana_changed(current_mana: float, max_mana: float)
signal player_exp_changed(current_exp: int, required_exp: int, current_level: int)
signal player_leveled_up(new_level: int)
signal player_stats_changed()
signal active_character_swapped(new_character_data: Resource)

# Skill events
signal skill_cast(slot: String, skill_data: Resource)
signal skill_cooldown_updated(slot: String, current_cooldown: float, max_cooldown: float)

# Game Mode & Wave events
signal game_mode_changed(new_mode: int)
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal endless_stats_updated(survival_time: float, wave: int, kills: int)
signal game_over(stats: Dictionary)

# Cards, inventory, and gacha events
signal card_selected(card_data: Resource)
signal item_picked_up(item_data: Resource, amount: int)
signal weapon_equipped(weapon_data: Resource)
signal character_unlocked(character_id: String)
signal faith_resonance_upgraded(character_id: String, new_rank: int)
signal currency_changed(new_amount: int)
signal gacha_pull_completed(results: Array)

# World events
signal map_transition_requested(target_map_path: String, spawn_point_id: String)
signal aggro_state_changed(is_chased: bool)
