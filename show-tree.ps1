# show-tree.ps1

function Show-DirectoryTree {
    param (
        [string]$Path = ".", # 基準となるパス (デフォルトはカレントディレクトリ)
        [int]$Depth = 0, # 現在の階層の深さ
        [string[]]$Exclude = @("node_modules", ".nuxt", "output", "dist", ".git", ".vscode") # 除外したいディレクトリ名のリスト
    )

    # インデント文字列を生成
    $indent = "  " * $Depth # スペース2つでインデント

    # 現在のパス内のアイテムを取得 (隠しファイルも含む)
    $items = Get-ChildItem -Path $Path -Force | Sort-Object { -not $_.PSIsContainer }, Name # ディレクトリを先に、名前順でソート

    foreach ($item in $items) {
        # 除外リストに含まれるかチェック
        $isExcluded = $false
        foreach ($excludeName in $Exclude) {
            if ($item.Name -eq $excludeName) {
                $isExcluded = $true
                break
            }
        }
        if ($isExcluded) {
            continue # 除外対象の場合はスキップ
        }

        # アイテム名を表示
        # ディレクトリには / を付けるなど、好みに応じて表示を調整可能
        $displayName = $item.Name
        # if ($item.PSIsContainer) { $displayName += "/" } # ディレクトリに / を付ける例

        Write-Host "$indent$displayName"

        # ディレクトリの場合は再帰的に呼び出し
        if ($item.PSIsContainer) {
             Show-DirectoryTree -Path $item.FullName -Depth ($Depth + 1) -Exclude $Exclude
        }
    }
}

# プロジェクトのルートディレクトリで関数を実行
# 除外リストをカスタマイズしたい場合は、以下の行の $Exclude 配列を編集してください。
Show-DirectoryTree -Path "." -Exclude @("node_modules", ".nuxt", "output", "dist", ".git", ".vscode")
