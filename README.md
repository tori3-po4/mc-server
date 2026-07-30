# x86_64 Paper Minecraft server

[`itzg/minecraft-server`](https://github.com/itzg/docker-minecraft-server) をベースにした、
Docker Compose 用の Minecraft Java Edition サーバー構成です。

- Paper、Java、設定ファイルの取得処理を自作しない
- `linux/amd64` を Compose で固定
- Paper のデータをホームディレクトリ内の `~/srv/data/` に保存
- Paper のバージョンとビルドを固定
- EULA に明示的に同意するまで起動しない

## Paper を起動する

Docker Engine または Docker Desktop と、Docker Compose v2 が必要です。

```sh
cp .env.example .env
```

`.env` を開き、[Minecraft EULA](https://aka.ms/MinecraftEULA) を確認したうえで、
同意する場合だけ次の値へ変更します。

```dotenv
EULA=TRUE
```

イメージを取得して起動します。

```sh
docker compose pull
docker compose up -d
docker compose logs -f mc
```

停止と再起動:

```sh
docker compose stop
docker compose restart mc
```

Minecraft の管理コマンド:

```sh
docker compose exec mc rcon-cli list
docker compose exec mc rcon-cli say Server maintenance starts soon
```

## OP権限を管理する

OP（Operator）は、`/gamemode`、`/give`、`/tp`、`/difficulty`、`/ban`、
`/stop`などの管理コマンドを使用できる権限です。信頼できるプレイヤーだけに付与してください。

実行中のサーバーで、Minecraft Java Editionのプレイヤー名を指定して付与します。

```sh
docker compose exec mc rcon-cli op プレイヤー名
```

例:

```sh
docker compose exec mc rcon-cli op ToriyamaIori
```

解除する場合:

```sh
docker compose exec mc rcon-cli deop ToriyamaIori
```

付与情報は `~/srv/data/ops.json` に保存されるため、コンテナを再起動しても維持されます。
OPを付与しても、ゲームモードは自動的にクリエイティブへ変わりません。
また、プラグイン固有のコマンドには別の権限設定が必要な場合があります。

現在の参加者を確認する場合:

```sh
docker compose exec mc rcon-cli list
```

全プレイヤーへメッセージを送る場合:

```sh
docker compose exec mc rcon-cli say "5分後にメンテナンスを開始します"
```

プレイヤー名のなりすましを防ぐため、特別な理由がなければ `.env` の
`ONLINE_MODE=TRUE`を維持してください。

サーバーデータは `~/srv/data/` に残ります。
コンテナを作り直しても、このディレクトリを削除しない限りワールドは残ります。

## ワールドを切り替える

使用するワールドは `.env` の `LEVEL` で選択します。既定値は次のとおりです。

```dotenv
LEVEL=world
SEED=
```

新しいワールドへ切り替える場合は、サーバーを停止してから `LEVEL` を変更します。
`SEED` は新規生成時だけ使用され、空欄の場合はランダムになります。

```sh
docker compose stop
```

```dotenv
LEVEL=world2
SEED=123456789
```

再度起動すると、次のディレクトリが新規生成されます。

```text
~/srv/data/world2/
~/srv/data/world2_nether/
~/srv/data/world2_the_end/
```

```sh
docker compose up -d
docker compose logs -f mc
```

以前のワールドは削除されません。戻す場合は `LEVEL=world` に変更して再起動します。
ワールド名には英数字、ハイフン、アンダースコアの使用を推奨します。

## Paper プラグイン

Paper では Forge/Fabric の Mod ではなく、Bukkit/Paper 用プラグインを使います。

1. 利用する Minecraft/Paper バージョンに対応したプラグイン JAR を入手する
2. JAR を `paper-plugins/` に置く
3. `docker compose restart mc` を実行する
4. `docker compose logs -f mc` でロード結果を確認する

`paper-plugins/` は読み取り専用でコンテナへ渡され、itzg の `PLUGINS` 機能が
`/data/plugins` を同期します。追加・削除後は必ず再起動してください。

## Paper の更新

現在の既定値は Paper `26.1.2` build `74` と Java 25 です。更新前には必ず
`~/srv/data/` をバックアップしてください。`.env` の
`MINECRAFT_VERSION` と `PAPER_BUILD` を更新してから、次を実行します。

```sh
docker compose pull
docker compose up -d
docker compose logs -f mc
```

実験ビルドを使う場合は Compose の `environment` に
`PAPER_CHANNEL: experimental` を追加します。本番ワールドには安定ビルドを推奨します。

## 将来 Modpack を導入する場合

Paper に Forge/Fabric/NeoForge 用 Mod を追加することはできません。Modpack 専用の
Compose ファイルを新しく作り、Paper とは別のデータボリュームで起動します。

1. `~/srv/data/` をバックアップする
2. Modpack の配布ページで、Minecraft、Mod loader、Java の対応バージョンを確認する
3. `compose.yaml` を `compose.modpack.yaml` などの別名でコピーする
4. `TYPE`、`PAPER_BUILD`、`PLUGINS` を削除する
5. Modrinth なら次の環境変数を設定する

   ```yaml
   MODPACK_PLATFORM: MODRINTH
   MODRINTH_MODPACK: "<Modpackのslug、ID、またはページURL>"
   ```

6. CurseForge なら次の環境変数を設定する

   ```yaml
   MODPACK_PLATFORM: AUTO_CURSEFORGE
   CF_PAGE_URL: "<ModpackのページURL>"
   ```

7. `image` を Modpack 指定の Java バージョンへ変更する
8. 公開ポートを Paper と同時起動するなら `25566:25565` などへ変更する
9. Paper の `~/srv/data/` は共有せず、Modpack 用の別ディレクトリを `/data` に割り当てる
10. EULA 同意後、別の Compose ファイルとして起動する

```sh
docker compose -f compose.modpack.yaml pull
docker compose -f compose.modpack.yaml up -d
docker compose -f compose.modpack.yaml logs -f mc
```

参加者側にも、サーバーと同じ Modpack とバージョンを導入します。Paper のワールドを試験移行する
場合は元ボリュームを共有せず、必ずバックアップのコピーを使用してください。

## バックアップと移行

アップデートの前にはサーバーを停止して、`~/srv/data/` をバックアップしてください。

## 参考

- [itzg: Paper server type](https://docker-minecraft-server.readthedocs.io/en/latest/types-and-platforms/server-types/paper/)
- [itzg: Java image tags](https://github.com/itzg/docker-minecraft-server/blob/master/docs/versions/java.md)
- [itzg: Modrinth Modpacks](https://docker-minecraft-server.readthedocs.io/en/latest/types-and-platforms/mod-platforms/modrinth-modpacks/)
- [itzg: Auto CurseForge](https://docker-minecraft-server.readthedocs.io/en/latest/types-and-platforms/mod-platforms/auto-curseforge/)
- [PaperMC: Getting started](https://docs.papermc.io/paper/getting-started/)
