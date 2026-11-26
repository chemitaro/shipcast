package spec

schema: "specdock/v1"

assurance: {
	level:  "standard"
	reason: "新しい道具を一から作る。外への投稿はせず、日誌は手元の別の置き場に書くので、失敗しても既存のrepositoryや外部に影響せず、作り直せる"
}

purpose: "AIエージェント（ソフトウェアファクトリー）が進めた開発を、本人が毎朝読んで理解できるように、プロジェクトごと・日付ごとの開発日誌を自動で作る。おまけとして、ネタポイントがたまったら発信の下書きを出す。"

background: """
開発がほぼ自動で進むと、物事は進むが、本人は「何が起き、なぜそうなり、自分は何を知っておくべきか」を追えなくなる。commitやPRは機械の記録で、人が読み通す形ではない。shipcastは、その日の出来事をGit・SpecDock・Orcaの会話から集め、安いモデルで分析して話題（Story）にまとめ、Gemini（Antigravity）が読みやすい文体で日誌を書く。日誌は独自タグ付きのMarkdownでGitの外に置き、Webページで読む。

経緯と本人の決定は、repositoryの `content/decisions/` と `content/deliberations/20261126-concept.md` にある。
"""

includes: [
	"設定ファイルに登録した、SpecDockを使うrepositoryの日誌",
	"Git・SpecDock（必須）とOrcaの会話の記録（任意）からの収集",
	"分析のモデルと書き手のモデルを設定で選べる経路（今回は分析にCodex、書き手にAntigravityのGemini 4 Neon）",
	"独自タグ付きMarkdownの日誌と、それをWebページに描く配信（Tailscaleで読む想定）",
	"毎晩3時の自動実行",
	"おまけ：ネタポイントの印とXの投稿の下書き",
]

excludes: [
	"X・note・Redditなどへの投稿（投稿は本人が行う）",
	"noteの記事とRedditの投稿の下書き（後で）",
	"日誌の外への公開（読み手は本人だけ）",
	"対象のrepositoryへの書込み",
]

requirements: {
	"R-01": {
		title: "登録したrepositoryごとに、日付ごとの日誌ができる"
		text:  "設定ファイルに登録したrepositoryの、指定した日の出来事から、1つのrepositoryにつき1日1本の日誌ができる。"
		acceptance: [
			"`shipcast write --repo <id> --date <日付>` で、日誌の置き場に `<repo>/<年>/<日付>.md` ができる",
			"出来事のない日は、短い1本（「大きな動きなし」）になる",
		]
	}
	"R-02": {
		title: "日誌の材料を、GitとSpecDockから必ず、Orcaの会話の記録からはあれば集める"
		acceptance: [
			"Gitのcommitとmerge、SpecDockのScopeとtodoの変化が、出来事として集まる",
			"Orcaが動いていれば、そのrepositoryでの会話の記録が出来事として集まる",
		]
	}
	"R-03": {
		title: "分析は安いモデル、文章は書き手のモデルが行い、どちらも設定で選べる"
		text:  "今回の既定は、分析がCodex（GPT-6.2 Sol。より安いモデルで足りるならそれ）、書き手がAntigravity（`agy -p`）のGemini 4 Neon。"
		acceptance: [
			"設定の `models.analyst` と `models.writer` を変えるだけで、使うモデルの経路が変わる",
			"試験は偽物の経路（`fake`）で、外部のモデルを呼ばずに通る",
		]
	}
	"R-04": {
		title: "日誌は独自タグ付きのMarkdownでGitの外に置き、Webページで読める"
		acceptance: [
			"日誌のファイルは、SpecDockの説明資料と同じデザインシステムのタグ（`:::summary` など）を使うMarkdownである",
			"`shipcast serve` を動かすと、ブラウザーで表紙・一覧・各日の日誌が読める",
			"Tailscaleで、手元の配信をtailnetの端末から読める手順がある",
		]
	}
	"R-05": {
		title: "毎晩3時に、全repositoryの前日の日誌が自動でできる"
		acceptance: ["定期の実行を登録すると、毎日3時に `shipcast run` が動き、前日の日誌ができる"]
	}
	"R-06": {
		title: "ネタポイントがたまると、日誌に印が付き、Xの下書きを作れる"
		acceptance: [
			"話題ごとのネタポイントがしきい値を超えると、日誌に「発信の芽」の囲みが出る",
			"`shipcast draft x --repo <id>` で、Xの投稿の下書きが手元にできる",
		]
	}
	"R-07": {
		title: "外へ投稿せず、対象のrepositoryを書き換えない"
		acceptance: [
			"shipcastには、外部のサービスへ投稿する処理がない",
			"収集は読むだけの操作（`git fetch`、checkout、indexを書き換える操作をしない）",
		]
	}
}

failures: {
	"F-01": {
		title: "モデルの呼び出しが失敗しても、集めた材料を失わず、次の実行で書き直せる"
	}
	"F-02": {
		title: "秘密情報らしい文字列は、外部のモデルに渡す前に伏せる"
	}
	"F-03": {
		title: "Orcaがない・読めないときは、Orcaなしで日誌を作る"
	}
	"F-04": {
		title: "エージェント（Claude Code・Codex・Orcaの作業者）の中からは、Antigravityの経路を呼ばない"
		text:  "Antigravityの規約は、第三者のエージェントやアプリで `agy` を包む使い方を個人のプランで認めていない。shipcastの夜の処理と本人の手動の実行だけが呼ぶ。"
	}
}

constraints: [
	"repositoryはpublic。個人の設定、状態、日誌はrepositoryの外に置く",
	"費用はサブスクリプションの範囲（Codex、Antigravity）。従量のAPIは使わない",
	"ハッカソン（2時間）では、仕様のレビューと品質ゲートを行わない（本人の決定）",
]

decisions: [
	"中心は開発日誌、発信はおまけ（`content/decisions/20261126-journal-first.md`）",
	"日誌は独自タグ付きのMarkdown、Gitの外、Tailscaleで読む、夜3時に自動（`content/decisions/20261126-journal-format-and-hackathon-plan.md`）",
	"Orcaの会話の記録は、分析と書き手のモデルに全文を渡してよい（秘密らしい文字列は伏せる）",
]

questions: [
	"GPT-6.2より安いCodexのモデル（Luna など）の正確な名前と、分析に足りるか（E3で確かめる）",
	"Orca CLIで、repositoryと期間を指定して会話の記録を読む方法（E2で確かめる）",
	"`agy -p` でモデル・思考の深さ・道具の禁止を指定する引数（E3で確かめる）",
]
