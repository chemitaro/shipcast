package spec

design: {
	"D-01": {
		title: "経路の部品（`shipcast.models`）"
		text: """
		`Route` は `complete(prompt: str, *, system: str, want_json: bool) -> str`。

		| 経路 | 呼び方（実装の最初に `--help` で確かめる） |
		|---|---|
		| `codex` | `codex exec -m <model> -c model_reasoning_effort=<effort> --sandbox read-only --skip-git-repo-check -`（プロンプトは標準入力） |
		| `antigravity` | `agy -p <prompt> --output-format json`。モデルと思考の深さの指定、道具の禁止。`--dangerously-skip-permissions` は使わない |
		| `claude` | `claude -p --model <model> --tools ""`（予備） |
		| `fake` | 入力から決まった応答を返す（試験とデモの予行） |

		すべての経路は、共通の入口（`GuardedRoute`）で、`antigravity` の守り → `redact()` → 経路の実装、の順に通る。時間の上限（既定10分）を付ける。子のプロセスを作る関数は差し替えられ、試験では偽のものを使う。
		"""
		satisfies: ["R-01", "F-02", "F-03"]
	}
	"D-02": {
		title: "まとめる（`shipcast.analyze`）"
		text:  "出来事をJSONにして分析のモデルに渡し、`stories` の配列をJSONで受け取る。プロンプトは `src/shipcast/prompts/analyze.md`。結果は `Store.save_stories` で保存してから書く段へ進む。"
		satisfies: ["R-02", "F-01"]
	}
	"D-03": {
		title: "書く（`shipcast.write`）"
		text:  "話題の骨組み（JSON）を書き手に渡し、本文のMarkdownを受け取る。プロンプトは `src/shipcast/prompts/write.md`（文体、使ってよいタグ、創作の禁止）。前付けと「発信の芽」はshipcastが機械で付ける。一時ファイルに書いてから置き換える。"
		satisfies: ["R-03", "R-04", "F-01", "F-04"]
	}
	"D-04": {
		title: "日誌のMarkdownの形"
		text: """
		パスと前付けは、全Epicの共通の契約（epic-00002 の D-05）に従う。本文はデザインシステムのタグを使う（SpecDockの説明資料と同じ）。

		```markdown
		---
		title: shipcast の開発日誌 2026-11-26
		lead: 今日の要約の1〜2文
		category: 開発日誌
		date: 2026-11-26
		repo: shipcast
		analyst: codex/gpt-6.2-sol
		writer: antigravity/gemini-4-neon
		generated_at: 2026-11-27T03:02:11+09:00
		---

		:::summary 今日の要約
		- 3〜5行
		:::

		:::warning あなたが知っておくべきこと
		- 方針に関わる変更、危うい点
		:::

		## 今日の物語
		（です・ます調の読み物。話題ごとに ### の小見出し。仕様のIDやPRへのリンク）

		:::checklist あなたを待っていること
		- 本人待ちのtodo
		:::

		:::metrics
		- 5 | merge | 
		- 3 | 閉じたIssue |
		:::

		:::tip 発信の芽（ネタポイント 7）
		- この話題はXに書けます（E5が D-05 の拡張点で付ける）
		:::
		```
		出来事のない日は、前付けと「大きな動きはありませんでした。」の1行。
		"""
		satisfies: ["R-03", "R-04"]
	}
	"D-05": {
		title: "日誌の組み立てと拡張点"
		text: """
		`build_entry(repo, day, stories, events, body_md, *, extensions) -> str`（iss-00016）。

		- `events` から `:::metrics` を数える（書き手に数えさせない）。
		- `extensions` は `JournalExtension`（`render(repo, day, stories, events) -> str | None`）の一覧。既定の一覧 `shipcast.write.EXTENSIONS` は、このEpicでは空。E5の iss-00019 が「発信の芽」を登録する。
		"""
		satisfies: ["R-05", "R-06"]
	}
}
