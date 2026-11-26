package spec

design: {
	"D-01": {title: "`shipcast.model`", text: "dataclass（`frozen=True`）と `to_json`・`from_json`。`event_id(source, repo_id, native_id)` は sha256 の先頭16桁。", satisfies: ["R-01", "R-03"]}
	"D-02": {title: "`shipcast.state.Store`", text: "`Store(state_dir)` が `state.sqlite3` を開き、表を作る（epic-00002 の D-04）。`add_events`、`events_for(repo, date)`、`save_stories`、`stories_for`、`record_run`、`add_neta`、`neta_balance(repo)`。", satisfies: ["R-02", "R-03"]}
	"D-03": {title: "日誌の契約の関数", text: "epic-00002 の D-05。`journal_path`、`JournalMeta`（dataclass）、`read_frontmatter`、`write_frontmatter`。", satisfies: ["R-04"]}
}
