package spec

slices: {
	"iss-00019": {covers: ["R-01", "R-02"], text: "台帳と日誌の印"}
	"iss-00020": {covers: ["R-03"], text: "Xの下書き", after: ["iss-00019"]}
}

verification: "fake の経路で、ポイントが閾値を超えた日の日誌に印が出て、`draft x` で下書きができる。"
