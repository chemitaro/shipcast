package spec

design: {
	"D-01": {
		title: "台帳への加算（`Store.save_stories`）と未消化の話題（`Store.unconsumed_stories`）"
		text: """
		epic-00006 の D-01。

		- `save_stories(stories)`：今の `INSERT ... ON CONFLICT (id) DO UPDATE` と同じ `with self._conn:` の取引の中で、各話題について `INSERT OR IGNORE INTO neta_ledger (story_id, repo_id, points, consumed) VALUES (?, ?, ?, 0)` を行う（`add_neta` と同じ文）。戻り値（話題の表で変わった行の数）は今のまま。`stories` は一度だけ読む（`Iterable` を list にしてから2つの文に使う）。
		- 記録済みの `story_id` は、点数を変えて保存し直しても `points`・`consumed` を変えない。
		- `add_neta`・`neta_balance`・`unconsumed_neta`・`consume_neta` は変えない。
		- 新しい `unconsumed_stories(repo_id: str, *, limit: int | None = None) -> list[Story]`：`neta_ledger` の `repo_id` が一致し、`consumed = 0` で `points > 0` の行を、`stories` の表と `story_id = id` で結び、`points DESC, neta_ledger.rowid` の順に `Story.from_json` で返す。`stories` の表にない id は飛ばす。`limit` は1以上の整数のときだけ件数を絞る（`None` なら全件）。iss-00020 も使う。
		"""
		satisfies: ["R-01", "R-02"]
	}
	"D-02": {
		title: "「発信の芽」の部品 `shipcast.neta.NetaSprout`"
		text: """
		epic-00006 の D-02。新しい module `src/shipcast/neta.py`（`shipcast.write` を import しない。循環を避けるため）。

		```python
		SPROUT_TITLES = 3

		class NetaSprout:
		    def __init__(self, store: Store, threshold: int) -> None: ...
		    def render(
		        self, repo_id: str, day: date, stories: Sequence[Story], events: Sequence[Event]
		    ) -> str | None: ...
		```

		- `render` は `store.neta_balance(repo_id)` を読み、`threshold` 未満なら `None` を返す。以上なら `store.unconsumed_stories(repo_id, limit=SPROUT_TITLES)` の題名で、次の文字列を返す（`stories`・`events`・`day` は使わない）。

		```markdown
		:::tip 発信の芽（ネタポイント 7）
		- 題名A
		- 題名B
		:::
		```

		- 題名の行は、空白を1つにまとめ、`html.escape(quote=False)` で文字参照にし、先頭が `#:-*+=`~|` のどれかなら `\\` を前に付け、先頭の `数字.` `数字)` の印を打ち消す（`shipcast.write._inline` と同じ規則。生のHTMLと、囲み・見出し・番号の誤った解釈を防ぐ）。空になった題名は飛ばす。
		- 残高がしきい値以上でも題名が1件もなければ（点数1以上の話題の本体がない）、題名の行のない `:::tip 発信の芽（ネタポイント N）` と `:::` の2行を返す。
		- `threshold` は `Config.neta.threshold`（1以上）を受け取る。部品は検査しない。
		"""
		satisfies: ["R-02"]
	}
	"D-03": {
		title: "CLI への配線（`shipcast.write.journal_extensions` と `run`）"
		text: """
		```python
		def journal_extensions(store: Store, threshold: int) -> tuple[JournalExtension, ...]:
		    return (*EXTENSIONS, NetaSprout(store, threshold))
		```

		- `EXTENSIONS` は呼んだ時点の値を読む（試験の `monkeypatch` が効くように）。`EXTENSIONS` の既定は `()` のまま。
		- `run` は、各 repository の `write_day` に `extensions=journal_extensions(store, config.neta.threshold)` を渡す。ほかは変えない（拡張点の例外を repository ごとの失敗として出す今の扱いもそのまま）。
		- `write_day` の中の順は今のまま：`analyze`（話題と台帳の保存）→ `compose` → `build_entry`（拡張点の `render`）。そのため、その日の話題の点数を足した後の残高で印を決める。
		- iss-00021 の `shipcast run` は、同じ `journal_extensions` を渡せば同じ印が出る（申し送り）。
		"""
		satisfies: ["R-02"]
	}
}
