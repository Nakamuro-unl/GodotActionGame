extends Node2D

## InGameシーン: 入力処理・HUD・イベント管理。
## 描画は IngameRenderer、定数データは IngameData に分離。

const GameSessionScript = preload("res://scripts/systems/game_session.gd")
const GMS = preload("res://scripts/autoload/game_manager.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")
const VirtualPadScene = preload("res://scenes/ui/virtual_pad.tscn")
const SaveMgrScript = preload("res://scripts/systems/save_manager.gd")
const PopupScene = preload("res://scenes/ui/popup_display.tscn")
const Renderer = preload("res://scenes/ingame/ingame_renderer.gd")
const Data = preload("res://scenes/ingame/ingame_data.gd")
const Actions = preload("res://scenes/ingame/ingame_actions.gd")
const HudHelper = preload("res://scenes/ingame/ingame_hud.gd")
const PlatformUI = preload("res://scripts/systems/platform_ui.gd")
const AudioMgr = preload("res://scripts/systems/audio_manager.gd")
const ItemMenuScene = preload("res://scenes/ui/item_menu.tscn")
const ItemSysScript = preload("res://scripts/systems/item_system.gd")
const InventoryScene = preload("res://scenes/ui/inventory_screen.tscn")
const SkillSwapScene = preload("res://scenes/ui/skill_swap_dialog.tscn")
const GameOverScene = preload("res://scenes/ui/game_over_effect.tscn")
const ScreenEffectScene = preload("res://scenes/ui/screen_effect.tscn")

var session: Node
var _facing: Vector2i = Vector2i.DOWN
var _is_animating: bool = false
var _vpad: Node = null
var _popup: Node = null
var _item_menu: Node = null
var _item_sys: Node = null
var _inventory: Node = null
var _skill_swap: Node = null
var _game_over_effect: Node = null
var _screen_fx: Node = null
var _renderer: Renderer
var _audio: Node
var _platform: int = PlatformUI.Platform.PC


func _ready() -> void:
	_renderer = Renderer.new()
	_renderer.setup($MapLayer, $EntityLayer)

	_audio = AudioMgr.new()
	add_child(_audio)

	session = GameSessionScript.new()
	add_child(session)
	session.game_over.connect(_on_game_over)
	session.game_clear.connect(_on_game_clear)
	session.floor_changed.connect(_on_floor_changed)
	session.message.connect(_on_message)
	session.skill_slot_full.connect(_on_skill_slot_full)
	session.enemy_defeated_visual.connect(_on_enemy_defeated_visual)
	session.enemy_ghostified_visual.connect(_on_enemy_ghostified_visual)
	session.player_damaged_visual.connect(_on_player_damaged_visual)
	session.player_leveled_up_visual.connect(_on_level_up)
	session.combo_visual.connect(_on_combo)

	_vpad = VirtualPadScene.instantiate()
	add_child(_vpad)
	_vpad.direction_pressed.connect(_do_move)
	_vpad.face_pressed.connect(_turn_facing)
	_vpad.skill_pressed.connect(_do_skill)
	_vpad.wait_pressed.connect(_do_wait)
	_vpad.interact_pressed.connect(_do_interact)
	_vpad.menu_pressed.connect(_open_inventory)

	_popup = PopupScene.instantiate()
	add_child(_popup)

	_item_menu = ItemMenuScene.instantiate()
	add_child(_item_menu)
	_item_menu.item_selected.connect(_on_item_selected)

	_item_sys = ItemSysScript.new()
	add_child(_item_sys)

	_inventory = InventoryScene.instantiate()
	add_child(_inventory)
	_inventory.closed.connect(_on_inventory_closed)

	_skill_swap = SkillSwapScene.instantiate()
	add_child(_skill_swap)
	_skill_swap.slot_selected.connect(func(_idx: int) -> void: _update_hud())
	_skill_swap.cancelled.connect(func() -> void: pass)

	_game_over_effect = GameOverScene.instantiate()
	add_child(_game_over_effect)
	_game_over_effect.finished.connect(_on_game_over_finished)

	_screen_fx = ScreenEffectScene.instantiate()
	add_child(_screen_fx)

	# セーブデータのロード or 新規ゲーム
	var gm: Node = get_node_or_null("/root/GameManager")
	var loaded: bool = false
	if gm and gm.should_load_save:
		var sm: Node = SaveMgrScript.new()
		loaded = sm.load_game(session)
		sm.free()
		gm.should_load_save = false

	if not loaded:
		session.start_new_game(randi())

	_renderer.rebuild_map(session.grid)
	_renderer.update_entities_immediate(session.player.grid_pos, session.enemies, $Camera2D)
	_update_hud()
	_update_minimap()
	if loaded:
		_add_message("セーブデータをロードしました (%dF)" % session.current_floor)
	else:
		_add_message("ステージ1 - 石器時代 1F")

	_apply_platform_ui()


func _apply_platform_ui() -> void:
	_platform = PlatformUI.detect_platform()
	var ui_config: Dictionary = PlatformUI.get_ui_config(_platform)
	var screen_config: Dictionary = PlatformUI.get_screen_config(_platform)
	var layout: Dictionary = PlatformUI.get_hud_layout(_platform)

	# 画面向き
	PlatformUI.apply_screen_config(_platform)

	# ビューポート解像度
	var vp: Window = get_viewport()
	if vp:
		vp.content_scale_size = Vector2i(screen_config["width"], screen_config["height"])

	# カメラzoom
	$Camera2D.zoom = Vector2(screen_config["camera_zoom"], screen_config["camera_zoom"])

	# UI表示切替
	_vpad.visible = ui_config["show_virtual_pad"]
	$UILayer/SkillSlots.visible = ui_config["show_skill_slots_hud"]
	$UILayer/KeyHints.visible = ui_config["show_keyboard_hints"]
	if ui_config["show_keyboard_hints"]:
		$UILayer/KeyHints.text = PlatformUI.get_keyboard_hints()

	# HUDレイアウト適用
	$UILayer/HUD.offset_top = layout["hud_top_y"]
	$UILayer/SkillSlots.offset_top = layout["skill_slots_y"]
	$UILayer/MessageLog.offset_top = layout["message_log_y"]

	# ミニマップ
	var minimap_rect: TextureRect = $UILayer/Minimap
	if minimap_rect:
		minimap_rect.offset_left = layout["minimap_x"]
		minimap_rect.offset_top = layout["minimap_y"]
		minimap_rect.custom_minimum_size = Vector2(layout["minimap_size"], layout["minimap_size"])


func _process(_delta: float) -> void:
	var debug_label: Label = $UILayer/DebugInfo
	if debug_label:
		var fps: int = int(Performance.get_monitor(Performance.TIME_FPS))
		var nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var draw: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		debug_label.text = "FPS:%d  Nodes:%d  Draw:%d" % [fps, nodes, draw]


# --- 入力処理 ---

func _unhandled_input(event: InputEvent) -> void:
	if session == null or _is_animating:
		return
	if _popup and _popup.is_showing():
		return
	if _item_menu and _item_menu.is_showing():
		return
	if _inventory and _inventory.is_showing():
		return
	if _skill_swap and _skill_swap.is_showing():
		return

	if event is InputEventKey and event.pressed and event.shift_pressed:
		if event.keycode == KEY_UP or event.keycode == KEY_W:
			_turn_facing(Vector2i.UP); return
		elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
			_turn_facing(Vector2i.DOWN); return
		elif event.keycode == KEY_LEFT or event.keycode == KEY_A:
			_turn_facing(Vector2i.LEFT); return
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			_turn_facing(Vector2i.RIGHT); return

	if event.is_action_pressed("ui_up"):
		_do_move(Vector2i.UP)
	elif event.is_action_pressed("ui_down"):
		_do_move(Vector2i.DOWN)
	elif event.is_action_pressed("ui_left"):
		_do_move(Vector2i.LEFT)
	elif event.is_action_pressed("ui_right"):
		_do_move(Vector2i.RIGHT)
	elif event is InputEventKey and event.pressed:
		var key: int = event.keycode
		if key >= KEY_1 and key <= KEY_6:
			_do_skill(key - KEY_1)
		elif key == KEY_SPACE or key == KEY_PERIOD:
			_do_wait()
		elif key == KEY_ENTER or key == KEY_KP_ENTER:
			_do_interact()
		elif key == KEY_I:
			_open_item_menu()
		elif key == KEY_ESCAPE:
			_open_inventory()


func _turn_facing(direction: Vector2i) -> void:
	_facing = direction
	_renderer.update_player_facing(_facing)
	_update_hud()
	_add_message("向きを変えた [%s]" % _direction_name(direction))


func _do_move(direction: Vector2i) -> void:
	_facing = direction
	_renderer.update_player_facing(_facing)
	if session.try_player_move(direction):
		_audio.play("step")
		_after_turn_animated()


func _do_skill(slot_index: int) -> void:
	if slot_index >= session.player.skill_slots.size():
		return
	var skill_id = session.player.skill_slots[slot_index]
	if skill_id == null or skill_id == "":
		_add_message("技がセットされていない")
		return
	var result: Dictionary = session.try_use_skill(slot_index, _facing)
	if result["success"]:
		var info: Dictionary = session.combat_system.get_skill_info(skill_id)
		_add_message("%s を使った! %d -> %d" % [info["name"], result["old_value"], result["new_value"]])
		_renderer.animate_attack(_facing, self)
		_audio.play("hit")
		_after_turn_animated()
	else:
		_audio.play("miss")
		_add_message("正面に敵がいない（向き: %s）" % _direction_name(_facing))


func _do_wait() -> void:
	session.score_system.register_turn()
	session.turn_manager.execute_player_action()
	_after_turn_animated()


func _do_interact() -> void:
	var result: Dictionary = session.interact(_facing)
	match result["type"]:
		"stairs":
			_screen_fx.fade_transition(0.6)
			await _screen_fx.fade_completed
			_renderer.rebuild_map(session.grid)
			_renderer.update_entities_immediate(session.player.grid_pos, session.enemies, $Camera2D)
			_update_hud()
			_update_minimap()
		"chest_knowledge":
			_audio.play("chest")
			_renderer.rebuild_map(session.grid)
			_update_hud()
			_show_knowledge_popup(result.get("knowledge_id", ""))
		"chest_item":
			_audio.play("chest")
			_renderer.rebuild_map(session.grid)
			_update_hud()
			_show_item_popup(result.get("item_id", ""))
		"gimmick_resolved":
			_renderer.rebuild_map(session.grid)
			_update_hud()


func _direction_name(dir: Vector2i) -> String:
	if dir == Vector2i.UP: return "上"
	if dir == Vector2i.DOWN: return "下"
	if dir == Vector2i.LEFT: return "左"
	if dir == Vector2i.RIGHT: return "右"
	return "?"


# --- ターン後の更新（アニメーション付き） ---

func _after_turn_animated() -> void:
	session.enemies = session.enemies.filter(
		func(e: Node) -> bool: return e.state != EnemyScript.EnemyState.DEFEATED
	)
	_renderer.cleanup_dead_sprites(session.enemies)
	_renderer.ensure_enemy_sprites(session.enemies)
	_update_hud()

	_is_animating = true
	var tween: Tween = _renderer.animate_turn(session.enemies, session.player.grid_pos, $Camera2D, self)
	tween.set_parallel(false)
	tween.tween_callback(func() -> void:
		_is_animating = false
		_renderer.update_enemy_visuals(session.enemies)
		_update_minimap()
	)


# --- ポップアップ ---

func _show_knowledge_popup(knowledge_id: String) -> void:
	Actions.show_knowledge_popup(_popup, session, knowledge_id)


func _show_item_popup(item_id: String) -> void:
	Actions.show_item_popup(_popup, item_id)


# --- スキルスロット満杯時の入れ替え ---

func _on_skill_slot_full(skill_id: String, skill_name: String) -> void:
	_skill_swap.show_dialog(session.player, skill_id, skill_name)


# --- ミニマップ ---

func _update_minimap() -> void:
	var minimap_rect: TextureRect = $UILayer/Minimap
	if minimap_rect:
		_renderer.render_minimap(session.grid, session.minimap, session.player.grid_pos, session.enemies, minimap_rect)


# --- インベントリ ---

func _open_inventory() -> void:
	_audio.play("menu")
	_inventory.show_inventory(session.player, session.knowledge_system)


func _on_inventory_closed() -> void:
	_update_hud()


# --- アイテムメニュー ---

func _open_item_menu() -> void:
	if session.player.items.is_empty():
		_add_message("アイテムを持っていない")
		return
	_item_menu.show_menu(session.player.items)


func _on_item_selected(index: int) -> void:
	var item_id: String = session.player.items[index] if index < session.player.items.size() else ""
	var result: Dictionary = Actions.use_item(_item_sys, session, index, _facing)
	if result["success"]:
		_add_message(result["message"])
		# 移動系アイテムは即座にマップ再描画
		if item_id in ["return_wing", "warp_stone"]:
			_renderer.update_entities_immediate(session.player.grid_pos, session.enemies, $Camera2D)
		if item_id in ["map_piece", "clairvoyance"]:
			_update_minimap()
		session.score_system.register_turn()
		session.turn_manager.execute_player_action()
		_after_turn_animated()
	else:
		_add_message(result.get("message", "使用できない"))


# --- HUD ---

func _update_hud() -> void:
	var p: Node = session.player
	HudHelper.update_status_bar($UILayer/HUD, p, session, _direction_name(_facing))
	HudHelper.update_skill_slots($UILayer/SkillSlots, p, session)
	HudHelper.update_vpad(_vpad, p, session)


# --- メッセージログ ---

var _messages: Array[String] = []

func _add_message(text: String) -> void:
	_messages.append(text)
	if _messages.size() > 3:
		_messages.pop_front()
	$UILayer/MessageLog.text = "\n".join(_messages)

func _on_message(text: String) -> void:
	_add_message(text)


# --- イベント ---

func _on_enemy_defeated_visual(enemy: Node) -> void:
	_audio.play("defeat")
	_renderer.animate_defeat(enemy, self)


func _on_enemy_ghostified_visual() -> void:
	_audio.play("ghost")


func _on_player_damaged_visual(_amount: int) -> void:
	_audio.play("damage")
	_renderer.animate_player_damage(self)


func _on_level_up(new_level: int) -> void:
	_audio.play("levelup")
	_screen_fx.level_up_effect(new_level)


func _on_combo(combo_count: int) -> void:
	_screen_fx.combo_popup(combo_count)


func _on_game_over() -> void:
	_store_result(false)
	_audio.stop_bgm()
	_audio.play("gameover")
	_game_over_effect.play()


func _on_game_over_finished() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.change_state(GMS.State.RESULT)


func _on_game_clear() -> void:
	_store_result(true)
	_add_message("GAME CLEAR!")
	await get_tree().create_timer(1.5).timeout
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.change_state(GMS.State.RESULT)


func _store_result(cleared: bool) -> void:
	var hp: int = session.player.hp if cleared else 0
	var mp: int = session.player.mp if cleared else 0
	var result: Dictionary = session.score_system.calculate_final(cleared, hp, mp)
	result["cleared"] = cleared
	result["floor_reached"] = session.current_floor
	result["enemies_defeated"] = session.score_system.total_kills
	result["max_combo"] = session.score_system.max_combo
	result["knowledge_count"] = session.score_system.knowledge_count
	result["total_turns"] = session.score_system.total_turns
	result["seed"] = session.seed_value
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.last_result = result

func _on_floor_changed(floor_number: int, stage: int) -> void:
	var stage_names: Array[String] = ["", "石器時代", "古代文明", "中世", "近代", "宇宙"]
	var stage_name: String = stage_names[stage] if stage < stage_names.size() else "???"
	_add_message("ステージ%d - %s %dF" % [stage, stage_name, floor_number])
	# ステージ別BGM
	var is_boss_floor: bool = floor_number % 5 == 0
	if is_boss_floor:
		_audio.play_bgm("boss")
	else:
		_audio.play_bgm("stage%d" % stage)
