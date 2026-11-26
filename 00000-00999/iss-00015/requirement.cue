package spec

schema: "specdock/v1"

assurance: {
	level:  "light"
	reason: "手元だけの新しい道具の一部で、PRを戻せば元に戻る"
}

purpose: "その日の出来事を、分析のモデルで話題（Story）にまとめ、保存する。"

requirements: {
	"R-01": {title: "関係する出来事を1つの話題にまとめ、what・why・notice・waiting・neta（0〜3）を付ける"}
	"R-02": {title: "応答は決まったJSONの形で受け、形が合わなければ1回だけ頼み直す"}
	"R-03": {title: "話題を状態に保存してから、次の段へ渡す"}
}

failures: {
	"F-01": {title: "2回とも形が合わないときは、失敗として記録し、出来事は残す"}
}
