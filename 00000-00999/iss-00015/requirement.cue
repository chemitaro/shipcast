package spec

schema: "specdock/v1"

assurance: {
	level:  "standard"
	reason: "話題（Story）の形とネタポイントは、執筆（iss-00016）とおまけ（iss-00019）が読む約束になる。誤ると日誌の中身が崩れるが、出来事は状態に残るので、PRを戻して分析し直せば回復できる"
}

purpose: "その日の出来事を、分析のモデルで話題（Story）にまとめ、保存する。実データはGitとSpecDockの収集（iss-00011、iss-00012）から来るが、試験は見本の出来事で行う。"

requirements: {
	"R-01": {
		title: "関係する出来事を1つの話題にまとめ、what・why・notice・waiting・neta（0〜3）を付ける"
		acceptance: ["fake の応答から、`event_ids` で出来事を指す話題ができ、各項目が埋まる", "neta.score は0〜3の整数で、範囲の外は形の誤りとする"]
	}
	"R-02": {
		title: "応答は決まったJSONの形で受け、形が合わなければ1回だけ頼み直す"
		acceptance: ["頼み直しのプロンプトに、前の応答の形の誤りが添えられる", "呼び出しは最大2回"]
	}
	"R-03": {
		title: "話題を状態に保存してから、次の段へ渡す"
		acceptance: ["`analyze` が返る前に、`Store.stories_for(repo, date)` で同じ話題が読める"]
	}
}

failures: {
	"F-01": {title: "2回とも形が合わないときは、失敗として記録し、出来事は残す"}
}
