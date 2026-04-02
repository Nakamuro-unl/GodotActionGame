# GDScript パフォーマンスガイド - アクションゲーム開発向け

> Godot 4.6 / GDScript 対象
> 参照: [Godot公式 - Performance](https://docs.godotengine.org/en/stable/tutorials/performance/index.html)

---

## 基本原則

1. **計測してから最適化する** - プロファイラで計測し、ボトルネックを特定してから対処する
2. **Godotの組み込み機能を使う** - 自前実装のGDScriptコードはC++組み込み関数より2桁遅い
3. **_process と _physics_process を正しく使い分ける**

---

## 1. Process関数の使い分け

```gdscript
# _physics_process: 物理演算・移動・衝突判定（固定60fps）
func _physics_process(delta: float) -> void:
    velocity = direction * speed
    move_and_slide()

# _process: UI更新・アニメーション・視覚エフェクト（可変fps）
func _process(delta: float) -> void:
    health_bar.value = current_health
```

- 移動・衝突・レイキャスト・`move_and_slide()` は必ず `_physics_process` に置く
- 不要なフレームでは `set_process(false)` / `set_physics_process(false)` で無効化する

---

## 2. ノードキャッシング

```gdscript
# NG: 毎フレーム get_node() を呼ぶ
func _process(delta: float) -> void:
    var turret = $Turret  # 毎フレームコスト発生
    direction = Vector2.UP.rotated(turret.rotation)

# OK: @onready でキャッシュ
@onready var turret: Node2D = $Turret

func _process(delta: float) -> void:
    direction = Vector2.UP.rotated(turret.rotation)
```

---

## 3. 型ヒントの活用

型ヒントを付けるとGodotが内部最適化を行える。全変数・全関数に型を付ける。

```gdscript
# NG
var speed = 200
var direction = Vector2.ZERO

func get_damage(base, multiplier):
    return base * multiplier

# OK
var speed: float = 200.0
var direction: Vector2 = Vector2.ZERO

func get_damage(base: float, multiplier: float) -> float:
    return base * multiplier
```

プロジェクト設定で以下の警告を有効にする：
- `UNTYPED_DECLARATION` - 型なし宣言を警告
- `UNSAFE_PROPERTY_ACCESS` - 安全でないプロパティアクセスを警告
- `UNSAFE_CAST` - 安全でないキャストを警告

---

## 4. 配列とループの最適化

```gdscript
# イテレータを使う（インデックスアクセスより約60%高速）
for enemy in enemies:
    enemy.update_ai()

# NG: インデックスアクセス
for i in range(enemies.size()):
    enemies[i].update_ai()
```

- 要素の削除は末尾から: `pop_back()` を優先、`pop_front()` は避ける
- ランダムアクセス・任意位置での削除が頻繁なら `Dictionary` を使う

---

## 5. 数学演算の最適化

```gdscript
# NG: distance_to() は平方根計算を含む
if position.distance_to(target) < 100.0:
    attack()

# OK: distance_squared_to() で平方根を回避
if position.distance_squared_to(target) < 10000.0:  # 100^2
    attack()
```

```gdscript
# 組み込み関数を使う（C++実装で高速）
var s: float = sign(value)           # 手動if文より高速
var p: int = nearest_po2(value)      # log/pow計算より高速
var mapped: float = remap(value, 0, 100, 0, 1)  # 手動計算より高速
```

---

## 6. 近傍検索の最適化（アクションゲームで頻出）

```gdscript
# NG: 全敵をループして距離計算
for enemy in all_enemies:
    if position.distance_squared_to(enemy.position) < range_sq:
        targets.append(enemy)

# OK: Area2D + CollisionShape2D で物理エンジンの空間分割を活用
@onready var detection_area: Area2D = $DetectionArea

func get_nearby_enemies() -> Array[Node2D]:
    return detection_area.get_overlapping_bodies()
```

---

## 7. オブジェクトプーリング（弾丸・エフェクト）

アクションゲームでは弾丸やエフェクトが大量生成される。毎回 `instantiate()` するのではなくプールで再利用する。

```gdscript
var bullet_pool: Array[Node2D] = []
var pool_size: int = 50

func _ready() -> void:
    for i in pool_size:
        var bullet: Node2D = bullet_scene.instantiate()
        bullet.set_process(false)
        bullet.visible = false
        add_child(bullet)
        bullet_pool.append(bullet)

func get_bullet() -> Node2D:
    for bullet in bullet_pool:
        if not bullet.visible:
            bullet.visible = true
            bullet.set_process(true)
            return bullet
    return null  # プール枯渇時

func return_bullet(bullet: Node2D) -> void:
    bullet.visible = false
    bullet.set_process(false)
    bullet.position = Vector2.ZERO
```

---

## 8. シーンのプリロード

```gdscript
# OK: プリロードでコンパイル時にロード
const EnemyScene: PackedScene = preload("res://scenes/enemy.tscn")

# NG: 実行時ロード（必要な場合のみ使用）
var enemy_scene: PackedScene = load("res://scenes/enemy.tscn")
```

- `preload()` はコンパイル時にロードされるため実行時コストゼロ
- 大量のリソースを一度にプリロードすると起動時間が増えるため、ステージ切り替え時に `load()` を使う場合もある

---

## 9. 条件分岐の最適化

```gdscript
# OR条件: 真になりやすいものを左に
if is_dead or health <= 0:
    die()

# 条件チェーン: 頻出ケースを上に
if state == State.IDLE:
    process_idle()
elif state == State.RUNNING:
    process_running()
elif state == State.ATTACKING:
    process_attacking()
# 稀なケースは下に
elif state == State.STUNNED:
    process_stunned()
```

- `if-elif` チェーンは `match` より約15-20%高速
- 再帰より反復処理を優先（スタックオーバーフロー回避にもなる）

---

## 10. print文の管理

```gdscript
# NG: リリースビルドにprint文を残す（高コスト・バッファ溢れの原因）
func _process(delta: float) -> void:
    print("position: ", position)

# OK: デバッグ時のみ出力
func _process(delta: float) -> void:
    if OS.is_debug_build():
        print_debug("position: ", position)
```

---

## 11. スクリプト設計

- スクリプトは **200-300行以下** に保つ。超えたら責務を分割する
- シグナルを活用して疎結合にする
- 物理ボディの選択:
  - `CharacterBody2D` - プレイヤー・敵キャラクター
  - `RigidBody2D` - 物理挙動が必要なオブジェクト
  - `StaticBody2D` - 動かない壁・床
  - `Area2D` - 当たり判定のみ（ダメージゾーン等）
- 人型キャラは `CapsuleShape2D` を使う（角が引っかからない）

---

## 12. GDScriptの限界とGDExtensionへの移行基準

以下のケースではGDExtension（C++）での実装を検討する：

- 手続き的な地形生成・ダンジョン生成
- 大量のAIエージェントの同時処理（100体以上）
- カスタム物理シミュレーション
- 画像処理・音声処理

移行前に必ずプロファイラで計測し、GDScriptがボトルネックであることを確認すること。

---

## 参考リンク

- [Godot公式 - General optimization tips](https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization.html)
- [GDQuest - Optimizing GDScript code](https://www.gdquest.com/tutorial/godot/gdscript/optimization-code/)
- [GDQuest - Making the most of Godot's speed](https://www.gdquest.com/tutorial/godot/gdscript/optimization-engine/)
