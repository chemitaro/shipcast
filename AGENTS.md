# shipcast エージェント契約

shipcastは、ソフトウェアファクトリーの時代の開発者のための、エージェントが書く開発日誌の道具です。おまけとして、ネタポイントがたまるとX・note・Redditなどへの発信の下書きを作ります。このGit repositoryは**public**です。構想と決定の経緯は`content/`にあります。

物理的にはCompany OSの`tools/shipcast/`に置いていますが、独立したGit repositoryです（GitHub: `chemitaro/shipcast`）。親のCompany OSの`AGENTS.md`はCompanyの文脈として読み、このrepositoryでの作業はこのファイルに従います。

## 保つこと

- **公開してよいものだけを置く。** このrepositoryはpublicです。秘密情報、個人情報、顧客のdata、未公開のProductの詳細（名前・仕様・計画）、ほかの非公開repositoryの中身を、コード・試験の見本・文書・commit messageに書きません。見本のdataは架空のものにします。
- **設定と状態はrepositoryの外。** 個人の設定（対象repository、公開範囲、NGワード）、素材、下書き、投稿の履歴はrepositoryの外（例 `~/.config/shipcast/`、`~/.local/state/shipcast/`）に置きます。`.gitignore`の該当行は誤って置いたときの安全網です。
- **外へ投稿しない。** shipcast自身も、作業するエージェントも、X・note・Redditなどへ投稿しません。投稿は人間が行います。外部のAPI（有料のものを含む）の利用、認証情報の設定は、本人の個別の明示が要ります。
- **読む対象を変えない。** 情報源のrepositoryは読むだけにします（`git fetch`、checkout、indexを書き換える操作をしません）。
- **外部のモデルに渡す前に絞る。** LLMに渡すことも外部への送信です。公開の方針で許可された情報だけを渡します。
- **決定の状態を取り違えない。** 採用できるのは本人だけです。採用済みの決定は`content/decisions/`の、本人の採用と書かれた記録です。エージェントや外部のモデルの分析は`content/deliberations/`に置き、採用までは案として扱います。

## 置き場

| もの | 場所 |
|---|---|
| 本人が採用した決定 | `content/decisions/` |
| 構想、分析、第三者の批評とその取捨、未決の事柄 | `content/deliberations/` |
| 仕様（要件・設計・計画） | SpecDock（`spec-dock/initiatives/`。使い方は`.agents/skills/spec-dock/`） |
| 一時的な作業 | `.workbench/`（Gitの外） |

## Gitと検証

- 検証を通した成果は`main`へ統合し、`git push origin main`します。force pushと公開済みの履歴の書換えはしません。
- 並行する実装はOrcaのworktreeとbranchで行い、PRで`main`に入れます。
- commitは自分が変えたpathだけを明示してstageします。
- 検証のcommand（この順に、手元とCIで同じものを流す）：
  1. `uv sync --locked`
  2. `uv run ruff check`
  3. `uv run pytest -q`
- 試験とエージェントの作業では、外部のモデルを呼ばない。モデルの経路は`fake`を使い、`agy`を呼ばない。
- PRはCI（`.github/workflows/ci.yml`）の合格を観測してから、統括がマージする。
