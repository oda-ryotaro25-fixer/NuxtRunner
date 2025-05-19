<template>
  <div id="app-container">
    <header class="app-header">
      <img src="/03A6CC26-FF7F-4F5E-A909-E48792B1F39E.png" alt="App Logo" class="header-logo" />
      <!-- 他にヘッダーに入れたいテキストやリンクがあればここに追加できます -->
      <!-- <span class="app-title">マイゲーム</span> -->
    </header>
    <main class="main-content">
      <NuxtPage />
    </main>
    <!-- フッターが必要な場合はここに追加 -->
    <!-- <footer class="app-footer">© 2023 My Game</footer> -->
  </div>
</template>

<script setup lang="ts">
// グローバルなスクリプトや状態管理の初期化などが必要な場合はここに記述します
</script>

<style>
/* グローバルなスタイルや、このapp.vue専用のスタイルを記述します */
/* 基本的なリセット */
html,
body,
#__nuxt,
/* Nuxtアプリのルート要素のID */
#app-container {
  /* このコンポーネントのルート要素のID */
  height: 100%;
  margin: 0;
  padding: 0;
  display: flex;
  /* ヘッダーとメインコンテンツを縦に並べるため */
  flex-direction: column;
  font-family: sans-serif;
  /* 基本フォント */
}

.app-header {
  background-color: #333;
  /* ヘッダーの背景色 (任意) */
  color: white;
  /* ヘッダーの文字色 (任意) */
  padding: 10px 20px;
  /* ヘッダーの内側の余白 */
  display: flex;
  /* ロゴやタイトルを横並びにするため */
  align-items: center;
  /* 要素を垂直方向中央揃え */
  /* ヘッダーを画面上部に固定する場合 (スクロールしても追従) */
  /* position: fixed; */
  /* top: 0; */
  /* left: 0; */
  /* width: 100%; */
  /* z-index: 1000; */
  /* 他の要素より手前に表示 */
  /* box-sizing: border-box; */
  /* paddingを含めてwidth 100%にするため */
}

.header-logo {
  height: 40px;
  /* ロゴの高さ (任意に調整してください) */
  width: auto;
  /* 幅は高さに合わせて自動調整 */
  margin-right: 15px;
  /* ロゴと次の要素の間の余白 (任意) */
}

.app-title {
  /* もしタイトルを表示する場合のスタイル例 */
  font-size: 1.5em;
  font-weight: bold;
}

.main-content {
  flex-grow: 1;
  /* 残りの利用可能なスペースをすべて使用 (ヘッダーの高さを除く) */
  overflow-y: auto;
  /* メインコンテンツが画面より大きい場合にスクロール可能にする */
  /* ヘッダーを position: fixed にした場合、コンテンツがヘッダーに隠れないようにする */
  /* padding-top: 60px; */
  /* ヘッダーの高さ (padding + logo height) に応じて調整 */
}

/* フッターのスタイル例 */
/*
.app-footer {
  background-color: #f0f0f0;
  color: #333;
  text-align: center;
  padding: 10px;
  font-size: 0.9em;
}
*/
</style>