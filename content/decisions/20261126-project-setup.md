# shipcastを独立したpublicのプロジェクトとして始める

- 状態: 本人の採用（2026-11-26の会話での本人の発言と選択）
- 決定者: 本人
- 決定日: 2026-11-26
- 経緯: [構想と第三者の批評](../deliberations/20261126-concept.md)

## 本人が決めたこと

1. 作るのは、日々の作業の記録から、外へ発信するための情報を集め、X・note・Redditなどへの投稿の文章を作る道具とする。ただの日報の道具にはしない。
2. 道具の名前（プロジェクト名）は`shipcast`とする（候補spec-herald・shipcast・tidecast・buildcastから本人が選択）。
3. Company OSの道具として、Company OSの`tools/`の下に独立したGit repositoryを作り、独立したプロジェクトとして管理する。SpecDockと連携する道具の1つと位置づける。
4. GitHubのrepositoryは最初からpublicで作る。
5. 議論と決定の集積はこのrepositoryで行い、決まったことをここへ移していく。

## 適用（エージェントの設計。本人が違うと判断すれば直す）

- LICENSEはMITとする。
- 個人の設定と実行の状態はrepositoryの外に置く。repositoryには公開してよい汎用のエンジンだけを置く。
- 決定は`content/decisions/`、分析と案は`content/deliberations/`、仕様はSpecDockに置く。

## まだ決まっていないこと

[構想](../deliberations/20261126-concept.md)の「未決の事柄」を参照。
