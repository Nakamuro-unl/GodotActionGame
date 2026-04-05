# GitHub Actions デプロイ設定手順

## 1. SSHデプロイキーを生成

```bash
ssh-keygen -t ed25519 -C "deploy-mathmage-web" -f deploy_key -N ""
```

## 2. 公開鍵をmathmage-webリポジトリに設定

1. https://github.com/Nakamuro-unl/mathmage-web/settings/keys
2. 「Add deploy key」
3. Title: `mathmage-deploy`
4. Key: `deploy_key.pub` の内容を貼り付け
5. 「Allow write access」にチェック

## 3. 秘密鍵をGodotActionGameリポジトリのSecretsに設定

1. https://github.com/Nakamuro-unl/GodotActionGame/settings/secrets/actions (リポジトリ名は適宜変更)
2. 「New repository secret」
3. Name: `DEPLOY_KEY`
4. Value: `deploy_key` (秘密鍵)の内容を貼り付け

## 4. mathmage-webのGitHub Pages設定

1. https://github.com/Nakamuro-unl/mathmage-web/settings/pages
2. Source: 「Deploy from a branch」
3. Branch: `main` / `/ (root)`
4. Save

## 5. 動作確認

masterブランチにpushすると自動で:
1. テスト実行
2. Webビルド
3. mathmage-webにデプロイ
4. GitHub Pagesに公開

URL: https://nakamuro-unl.github.io/mathmage-web/

手動実行: Actions タブ → 「Deploy Web Build」→ 「Run workflow」
