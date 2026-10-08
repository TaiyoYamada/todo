# 開発用のコマンド集。一覧は `make help`。
# macOS 標準の GNU Make 3.81 で動く書き方にしている。

SHELL := /bin/bash
.DEFAULT_GOAL := help

# --- 設定 ---------------------------------------------------------------------
# コマンドラインで上書きできる。
#   make build SCHEME=Todo-Prod
#   make test DESTINATION='platform=iOS Simulator,name=iPhone 17'
# 使えるシミュレータは `xcrun simctl list devices available` で確かめる。
PROJECT           ?= Todo.xcodeproj
SCHEME            ?= Todo-Dev
DESTINATION       ?= platform=iOS Simulator,name=iPhone 17 Pro
BUILD_DESTINATION ?= generic/platform=iOS Simulator
PACKAGE_PATH      ?= Packages/TodoKit
DERIVED_DATA      ?= DerivedData
RESULT_DIR        ?= build/reports
UI_TEST_TARGET    ?= TodoUITests

# TCA などの Swift マクロは、コマンドラインからのビルドでは事前の承認ができないので検証を飛ばす
XCODEBUILD_FLAGS  ?= -skipMacroValidation -skipPackagePluginValidation
SWIFT_TEST_FLAGS  ?=
XCBEAUTIFY_FLAGS  ?=

# xcbeautify が入っているときだけ、xcodebuild の出力を整形する
ifneq ($(shell command -v xcbeautify 2>/dev/null),)
XCPIPE := | xcbeautify $(XCBEAUTIFY_FLAGS)
else
XCPIPE :=
endif

# Todo.xcodeproj の中には Package.resolved だけがコミットされていることがあるので、
# ディレクトリではなく project.pbxproj の有無で「生成済みか」を判断する
PBXPROJ := $(PROJECT)/project.pbxproj

# $(call require,コマンド名): コマンドがなければ、入れ方を示して止める
require = @command -v $(1) >/dev/null 2>&1 || { echo "$(1) が見つかりません。'brew install $(1)' で入れてください。" >&2; exit 1; }

# --- セットアップ -------------------------------------------------------------
.PHONY: bootstrap
bootstrap: ## project.yml から Todo.xcodeproj を生成する(XcodeGen)
	$(call require,xcodegen)
	xcodegen generate

# プロジェクトがまだないときだけ生成する。ファイルを足したあとは `make bootstrap` をやり直す
$(PBXPROJ):
	@$(MAKE) bootstrap

# --- ビルド -------------------------------------------------------------------
.PHONY: build
build: $(PBXPROJ) ## アプリを iOS シミュレータ向けにビルドする(既定は Todo-Dev)
	set -o pipefail; xcodebuild build \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-destination "$(BUILD_DESTINATION)" \
		-derivedDataPath "$(DERIVED_DATA)" \
		$(XCODEBUILD_FLAGS) $(XCPIPE)

# --- テスト -------------------------------------------------------------------
.PHONY: test
test: test-domain test-app ## すべてのテストを実行する(test-domain のあとに test-app)

.PHONY: test-domain
test-domain: ## 純粋なロジックのテストを macOS 上で実行する(速い)
	swift test --package-path "$(PACKAGE_PATH)" $(SWIFT_TEST_FLAGS)

.PHONY: test-app
test-app: $(PBXPROJ) ## ユニットテストと UI テストをシミュレータで実行する
	rm -rf "$(RESULT_DIR)/Test.xcresult"
	set -o pipefail; xcodebuild test \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-destination "$(DESTINATION)" \
		-derivedDataPath "$(DERIVED_DATA)" \
		-resultBundlePath "$(RESULT_DIR)/Test.xcresult" \
		$(XCODEBUILD_FLAGS) $(XCPIPE)

.PHONY: test-ui
test-ui: $(PBXPROJ) ## UI テストだけをシミュレータで実行する
	rm -rf "$(RESULT_DIR)/UITest.xcresult"
	set -o pipefail; xcodebuild test \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-destination "$(DESTINATION)" \
		-derivedDataPath "$(DERIVED_DATA)" \
		-resultBundlePath "$(RESULT_DIR)/UITest.xcresult" \
		-only-testing:"$(UI_TEST_TARGET)" \
		$(XCODEBUILD_FLAGS) $(XCPIPE)

# --- 検査と整形 ---------------------------------------------------------------
.PHONY: lint
lint: ## SwiftLint と SwiftFormat で検査する(ファイルは変えない)
	$(call require,swiftlint)
	$(call require,swiftformat)
	swiftlint lint --config .swiftlint.yml --strict
	swiftformat --config .swiftformat --lint .

.PHONY: format
format: ## SwiftFormat で整形する(ファイルを書き換える)
	$(call require,swiftformat)
	swiftformat --config .swiftformat .

.PHONY: format-check
format-check: ## 整形が必要なファイルがないか確かめる(ファイルは変えない)
	$(call require,swiftformat)
	swiftformat --config .swiftformat --lint .

# --- 後片付け -----------------------------------------------------------------
.PHONY: clean
clean: ## ビルドの成果物とテスト結果を消す(生成した Todo.xcodeproj は残す)
	rm -rf "$(DERIVED_DATA)" "$(RESULT_DIR)" "$(PACKAGE_PATH)/.build"

# --- ヘルプ -------------------------------------------------------------------
.PHONY: help
help: ## このヘルプを表示する
	@echo "使い方: make <ターゲット> [変数=値 ...]"
	@echo
	@echo "ターゲット:"
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_-]+:.*## / {printf "  \033[36m%-13s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo
	@echo "変数(現在の値):"
	@echo "  SCHEME            $(SCHEME)"
	@echo "  DESTINATION       $(DESTINATION)"
	@echo "  BUILD_DESTINATION $(BUILD_DESTINATION)"
	@echo "  PACKAGE_PATH      $(PACKAGE_PATH)"
	@echo "  DERIVED_DATA      $(DERIVED_DATA)"
	@echo "  UI_TEST_TARGET    $(UI_TEST_TARGET)"
