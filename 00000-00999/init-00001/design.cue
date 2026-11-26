package spec

goals: [
	"集める・まとめる・書く・描くを分け、各段を差し替えられるようにする",
	"状態と日誌をrepositoryの外に置き、何度実行しても同じ日の日誌を作り直せるようにする",
]

current: "道具はない。開発の記録はGit・SpecDock・Orcaに散らばり、人が読む形の日誌はない。"
target:  "毎朝、tailnetのブラウザーで、プロジェクトごとの前日の日誌を読める。"

design: {
	"D-01": {
		title: "4段の流れ：集める → まとめる → 書く → 描く"
		text: """
		1. **集める（collector）**：Git・SpecDock・Orcaから、その日の出来事（Event）を集める。機械の処理だけで、モデルを使わない。
		2. **まとめる（analyst）**：安いモデルが、出来事を話題（Story）にまとめ、事実の骨組み（何を・なぜ・人が知るべきこと・人を待つこと・ネタポイント）を作る。
		3. **書く（writer）**：書き手のモデル（Gemini 4 Neon）が、骨組みから「要約＋読み物」の日誌の本文を書く。
		4. **描く（viewer）**：Markdownのファイルを、配信のときにデザインシステムでWebページにする。HTMLは保存しない。
		"""
		satisfies: ["R-01", "R-02", "R-03", "R-04"]
	}
	"D-02": {
		title: "置き場：設定・状態・日誌はrepositoryの外"
		text: """
		- 設定：`~/.config/shipcast/config.toml`（環境変数 `SHIPCAST_CONFIG` で変えられる）
		- 状態：`~/.local/state/shipcast/`（SQLiteの `state.sqlite3`、実行の記録、ログ）
		- 日誌：`~/.local/share/shipcast/journal/<repo>/<年>/<YYYY-MM-DD>.md`（設定の `journal_dir` で変えられる）
		- 1日は、その土地の時刻（既定 Asia/Tokyo）の0時から24時。3時の実行は前日を書く。
		"""
		satisfies: ["R-01", "R-07"]
	}
	"D-03": {
		title: "モデルの経路：名前で選ぶ差し替えの部品"
		text: """
		経路は `codex`、`antigravity`、`claude`、`fake` の名前で選ぶ。分析（`models.analyst`）と書き手（`models.writer`）に別々に指定する。入力はすべて、伏せる処理（redaction）を通してから渡す。`antigravity` の経路は、エージェントの中（環境変数 `CLAUDECODE`、`CODEX_*`、Orcaの作業者の印がある）では呼ばずに止まる。
		"""
		satisfies: ["R-03", "F-02", "F-04"]
	}
	"D-04": {
		title: "材料の保存と書き直し"
		text:  "集めた出来事とまとめた話題は、モデルの呼び出しの前に状態へ保存する。書く段が失敗しても、次の実行で同じ材料から書き直せる。日誌のファイルは一時ファイルに書いてから置き換える。"
		satisfies: ["F-01"]
	}
	"D-05": {
		title: "任意の連携の扱い"
		text:  "Orcaの収集は、Orcaが動いていない・CLIがない・読めないときに、警告を記録して空の結果を返す。GitとSpecDockの失敗は、そのrepositoryの日誌の失敗として記録する。"
		satisfies: ["F-03", "R-02"]
	}
	"D-06": {
		title: "夜の実行とおまけ"
		text:  "`shipcast run` が全repositoryを順に処理し、launchdが毎日3時に呼ぶ。ネタポイントは話題ごとにためて、しきい値を超えたら日誌に印を付け、`shipcast draft x` が下書きを作る。どちらも外へは送らない。"
		satisfies: ["R-05", "R-06", "R-07"]
	}
}

compatibility: "最初の版。データの約束には `schema = 1` を付け、後で変えるときは版を上げる。"

risks: [
	"Antigravityの規約は変わりやすい。2026-12-19に読み直す",
	"外付けvolumeのrepositoryは、launchdからの読み取りがmacOSの許可（TCC）で失敗しうる",
	"安いモデルの分析の質が足りないと、日誌が浅くなる",
]
