extends Control

## ユーザー名入力ダイアログ。Controlベースで確実にボタンイベントを受ける。
## iOS Safari対応: タップ時にJS bridgeで仮想キーボードを起動する。

signal name_submitted(player_name: String)

var _is_showing: bool = false
var _is_web: bool = false


func _ready() -> void:
	visible = false
	_is_web = OS.has_feature("web")
	$Panel/VBox/Buttons/BtnOK.pressed.connect(_on_submit)
	$Panel/VBox/Buttons/BtnSkip.pressed.connect(_on_skip)
	$Panel/VBox/NameInput.text_submitted.connect(func(_t: String) -> void: _on_submit())
	# iOS Safari: LineEditタップ時にJS bridgeでキーボード起動
	$Panel/VBox/NameInput.gui_input.connect(_on_name_input_gui)


func is_showing() -> bool:
	return _is_showing


func show_dialog() -> void:
	visible = true
	_is_showing = true
	$Panel/VBox/NameInput.text = ""
	# 非Web環境では従来通りgrab_focus、Webでは遅延フォーカス
	if not _is_web:
		$Panel/VBox/NameInput.grab_focus()
	else:
		# Webではユーザージェスチャーを待つためフォーカスしない
		# 代わりにLineEditクリック/タップでフォーカス+キーボード起動
		$Panel/VBox/NameInput.call_deferred("grab_focus")


## iOS Safari: LineEditへのタッチ/クリック時にJS経由でキーボードを起動
func _on_name_input_gui(event: InputEvent) -> void:
	if not _is_web:
		return
	if event is InputEventMouseButton and event.pressed:
		_open_ios_keyboard()


func _on_submit() -> void:
	var name_text: String = $Panel/VBox/NameInput.text.strip_edges()
	if name_text == "":
		name_text = "Anonymous"
	if name_text.length() > 12:
		name_text = name_text.substr(0, 12)
	visible = false
	_is_showing = false
	name_submitted.emit(name_text)


func _on_skip() -> void:
	visible = false
	_is_showing = false
	name_submitted.emit("Anonymous")


## iOS/Web: JavaScriptで隠しinputにフォーカスしキーボードを起動、結果をLineEditに反映
func _open_ios_keyboard() -> void:
	var js_code: String = """
	(function() {
		var existing = document.getElementById('godot-text-input');
		if (existing) { existing.remove(); }
		var inp = document.createElement('input');
		inp.id = 'godot-text-input';
		inp.type = 'text';
		inp.maxLength = 12;
		inp.setAttribute('autocomplete', 'off');
		inp.setAttribute('autocorrect', 'off');
		inp.setAttribute('autocapitalize', 'off');
		inp.style.position = 'fixed';
		inp.style.top = '40%';
		inp.style.left = '10%';
		inp.style.width = '80%';
		inp.style.height = '44px';
		inp.style.fontSize = '18px';
		inp.style.textAlign = 'center';
		inp.style.zIndex = '99999';
		inp.style.opacity = '1';
		inp.style.background = '#222';
		inp.style.color = '#fff';
		inp.style.border = '2px solid #f0c040';
		inp.style.borderRadius = '8px';
		inp.style.padding = '4px';
		inp.placeholder = 'Anonymous';
		document.body.appendChild(inp);
		inp.focus();
		inp.addEventListener('input', function() {
			window._godotTextValue = inp.value;
		});
		inp.addEventListener('keydown', function(e) {
			if (e.key === 'Enter') {
				window._godotTextSubmitted = true;
			}
		});
		inp.addEventListener('blur', function() {
			window._godotTextSubmitted = true;
		});
		window._godotTextValue = '';
		window._godotTextSubmitted = false;
	})();
	"""
	JavaScriptBridge.eval(js_code)
	# ポーリングでJS側の入力完了を監視
	_poll_js_input()


func _poll_js_input() -> void:
	while _is_showing:
		await get_tree().create_timer(0.1).timeout
		var submitted: bool = JavaScriptBridge.eval("window._godotTextSubmitted === true;")
		if submitted:
			var value: String = str(JavaScriptBridge.eval("window._godotTextValue || '';"))
			$Panel/VBox/NameInput.text = value
			JavaScriptBridge.eval("var el = document.getElementById('godot-text-input'); if(el) el.remove();")
			_on_submit()
			return
		# リアルタイムでLineEditに反映
		var current: String = str(JavaScriptBridge.eval("window._godotTextValue || '';"))
		if current != $Panel/VBox/NameInput.text:
			$Panel/VBox/NameInput.text = current


func _unhandled_input(event: InputEvent) -> void:
	if not _is_showing:
		return
	if event.is_action_pressed("ui_cancel"):
		if _is_web:
			JavaScriptBridge.eval("var el = document.getElementById('godot-text-input'); if(el) el.remove();")
		_on_skip()
		get_viewport().set_input_as_handled()
