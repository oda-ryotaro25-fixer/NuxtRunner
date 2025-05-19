<template>
    <div class="game-container" @mousedown="handleScreenInteractionStart" @mouseup="handleScreenInteractionEnd"
        @touchstart.prevent="handleScreenInteractionStart" @touchend="handleScreenInteractionEnd">
        <div class="player" :style="{ bottom: playerY + 'px', left: playerX + 'px' }">
            <!-- チャージバー -->
            <div v-if="isChargingJump || currentJumpChargeRatio > 0" class="charge-bar-container" :style="{
                position: 'absolute', // game-container 基準
                left: (playerX - 100) + 'px',
                bottom: (playerY + 1) + 'px',
                width: playerWidth + 'px' // プレイヤーの幅に合わせる
            }">
                <div class="charge-bar-fill" :style="{ width: currentJumpChargeRatio * 100 + '%' }"></div>
            </div>
        </div>

        <div class="ground" :style="{ backgroundPositionX: groundScrollX + 'px' }"></div>

        <!-- 障害物の描画 -->
        <template v-for="obstacleInst in obstacles" :key="obstacleInst.id">
            <div v-for="(part, partIndex) in obstacleInst.parts" :key="`${obstacleInst.id}-${partIndex}`"
                class="obstacle-part" :style="{
                    left: part.renderX + 'px',
                    bottom: part.renderY + 'px', /* renderY を使用 */
                    width: part.width + 'px',
                    height: part.height + 'px',
                    backgroundColor: part.color,
                }"></div>
        </template>

        <!-- スコア表示 -->
        <div class="score-display">Score: {{ score }}</div>

        <!-- ゲーム開始/ゲームオーバーメッセージ -->
        <div v-if="!gameStarted || gameOver" class="message-overlay" @click.stop>
            <div v-if="!gameStarted">
                <h1>Nuxt Runner</h1>
                <button @click="startGame">START</button>
            </div>
            <div v-if="gameOver">
                <h2>GAME OVER</h2>
                <p>Your Score: {{ score }}</p>
                <button @click="startGame">RETRY</button>
            </div>
        </div>
    </div>
</template>

<script setup lang="ts">

import { ref, reactive, onMounted, onUnmounted, computed } from 'vue';
// --- ゲーム設定 ---
const gameContainerWidth = 800;
const gameContainerHeight = 400;
const groundHeight = 50;
const playerHeight = 50;
const playerWidth = 50;
const minJumpPower = 10;    // 最小ジャンプ力
const maxJumpPower = 25;    // 最大ジャンプ力
const jumpChargeTimeMax = 500; // ジャンプチャージ最大時間 (ミリ秒)
const gravity = 1;    // 重力の強さ
const scrollSpeed = ref(5); // スクロール速度 (ピクセル/フレーム)

// --- 障害物設定 ---
const baseObstacleSpawnIntervalMin = 1100; // 出現間隔の最小値を少し短く
const baseObstacleSpawnIntervalMax = 2300; // 出現間隔の最大値を少し短く
let nextSpawnTime = 0;
let consecutiveSpawnCount = 0; // 連続出現カウント
const maxConsecutiveSpawns = 2; // 最大連続出現回数
const consecutiveSpawnInterval = 400; // 連続出現時の間隔 (ms)

// 障害物パーツの定義
interface ObstaclePartConfig {
    offsetX: number; // 親障害物の左上からのXオフセット
    offsetY: number; // 親障害物の左上からのYオフセット (下方向が正)
    width: number;
    height: number;
    color: string;
}

// プリセット用のパーツ設計図
interface ObstaclePartBlueprint {
    offsetX: number;
    offsetY: number;
    widthRange: [number, number];    // [min, max]
    heightRange: [number, number];   // [min, max]
    colorOptions: string[];
}

// 障害物全体のプリセット定義
interface ObstaclePreset {
    parts: ObstaclePartBlueprint[]; // Blueprintの配列に変更
    baseTotalWidth: number;
    baseTotalHeight: number;
    canBeFloating?: boolean;
    minYOffset?: number;
    maxYOffset?: number;
    spawnWeight: number;
}

// 障害物全体のタイプの定義
enum ObstaclePresetType {
    SingleLow,      // 単純な低い障害物 (サイズ変動)
    SingleHigh,     // 単純な高い障害物 (サイズ・Y変動)
    TallWall,       // 高い壁
    FloatingIsland, // 空中に浮く大きな島（複数のパーツで構成も可能）
    UnevenGround,   // 地面の凸凹 (複数のパーツで構成)
    VeryHighTrap,   // 非常に高い位置の小さなトラップ
}



const obstaclePresets: Record<ObstaclePresetType, ObstaclePreset> = {
    [ObstaclePresetType.SingleLow]: {
        parts: [{
            offsetX: 0,
            offsetY: 0,
            widthRange: [30, 80],
            heightRange: [25, 50],
            colorOptions: ['#CD853F', '#D2691E']
        }],
        baseTotalWidth: 50, baseTotalHeight: 40,
        spawnWeight: 30,
    },
    [ObstaclePresetType.SingleHigh]: {
        parts: [{
            offsetX: 0,
            offsetY: 0,
            widthRange: [25, 60],
            heightRange: [40, 70],
            colorOptions: ['#A0522D', '#8B4513']
        }],
        baseTotalWidth: 40, baseTotalHeight: 60,
        canBeFloating: true, minYOffset: playerHeight * 0.4, maxYOffset: playerHeight * 1.5,
        spawnWeight: 25,
    },
    [ObstaclePresetType.TallWall]: {
        parts: [{
            offsetX: 0,
            offsetY: 0,
            widthRange: [40, 70],
            // 高さは spawnObstacle で計算するか、ここで固定範囲にする
            // ここでは固定範囲の例
            heightRange: [
                gameContainerHeight * 0.4 - groundHeight, // getRandomInRange から具体的な範囲に変更
                gameContainerHeight * 0.8 - groundHeight  // 例: 最小高さを少し下げる
            ],
            colorOptions: ['#696969']
        }],
        baseTotalWidth: 55, baseTotalHeight: gameContainerHeight * 0.7 - groundHeight,
        spawnWeight: 15,
    },
    [ObstaclePresetType.FloatingIsland]: {
        parts: [
            {
                offsetX: 0,
                offsetY: 0,
                widthRange: [80, 150],
                heightRange: [30, 50],
                colorOptions: ['#8FBC8F']
            },
            {
                offsetX: 10,
                offsetY: -15, // 地面より上に出るのでマイナスオフセット
                widthRange: [60, 120],
                heightRange: [15, 25], // height: 20 から修正
                colorOptions: ['#2E8B57']
            }
        ],
        baseTotalWidth: 120, baseTotalHeight: 60,
        canBeFloating: true, minYOffset: playerHeight * 0.8, maxYOffset: gameContainerHeight * 0.5,
        spawnWeight: 10,
    },
    [ObstaclePresetType.UnevenGround]: {
        parts: [
            {
                offsetX: 0,
                offsetY: 0,
                widthRange: [40, 60],
                heightRange: [15, 30],
                colorOptions: ['#BDB76B']
            },
            {
                // offsetX を固定値または範囲にする (spawnObstacle での解釈を容易にするため)
                // ここでは例として固定値にする
                offsetX: 50, // getRandomInRange(30, 50) から固定値に変更 (または range で指定)
                offsetY: 0,
                widthRange: [30, 50],
                heightRange: [25, 40],
                colorOptions: ['#F0E68C']
            },
            {
                offsetX: 90, // getRandomInRange(70, 100) から固定値に変更
                offsetY: 0,
                widthRange: [20, 40],
                heightRange: [10, 25],
                colorOptions: ['#BDB76B']
            },
        ],
        baseTotalWidth: 120, baseTotalHeight: 40,
        spawnWeight: 15,
    },
    [ObstaclePresetType.VeryHighTrap]: {
        parts: [{
            offsetX: 0,
            offsetY: 0,
            widthRange: [20, 35],
            heightRange: [20, 35],
            colorOptions: ['#FF6347']
        }],
        baseTotalWidth: 30, baseTotalHeight: 30,
        canBeFloating: true, minYOffset: gameContainerHeight * 0.75 - groundHeight, maxYOffset: gameContainerHeight * 0.85 - groundHeight,
        spawnWeight: 5,
    }
};

enum ObstacleType {
    Low,      // 地面の障害物 (高さ・幅が変動)
    High,     // 空中の障害物 (Y座標・幅が変動)
    // もし明確に分けたいなら LowSmall, LowWide, HighNarrow などに戻してもOK
}


const obstacleConfigs: Record<ObstacleType, ObstacleConfig> = {
    [ObstacleType.Low]: {
        baseWidth: 30, minWidth: 20, maxWidth: 80, // 幅をランダムに
        baseHeight: 30, minHeight: 20, maxHeight: 45, // 高さをランダムに
        colors: ['#CD853F', '#D2691E', '#A0522D'], // Peru, Chocolate, Sienna
        spawnWeight: 60, // 60%くらいの確率で出るイメージ
    },
    [ObstacleType.High]: {
        baseWidth: 35, minWidth: 25, maxWidth: 50, // 幅をランダムに
        baseHeight: 50, // 高さは比較的一定でも良いかも
        colors: ['#8B4513', '#B8860B', '#BC8F8F'], // SaddleBrown, DarkGoldenRod, RosyBrown
        yOffsetMin: playerHeight * 0.5, // プレイヤーの半分の高さから
        yOffsetMax: playerHeight * 1.2, // プレイヤーの高さより少し上まで
        spawnWeight: 40,
    },
};

// --- プレイヤーの状態 ---
const playerX = 100; // プレイヤーのX座標 (固定)
const playerY = ref(groundHeight); // プレイヤーのY座標 (地面基準のbottom)
const playerVelocityY = ref(0);    // プレイヤーの垂直速度
const isJumping = ref(false);      // ジャンプ中フラグ
const isChargingJump = ref(false); // ジャンプチャージ中かどうかのフラグ 
let jumpChargeStartTime = 0;     // ジャンプチャージ開始時間
const currentJumpChargeRatio = ref(0); // チャージ割合 (0-1) を保持 

// --- 地面の状態 ---
const groundScrollX = ref(0); // 地面のスクロール位置

// --- 障害物の状態 ---
interface ObstacleInstance { // 実際に画面に出現する障害物のインスタンス
    id: number;
    presetType: ObstaclePresetType; // どのプリセットから作られたか
    x: number;           // この障害物群全体の左端のX座標
    y: number;           // この障害物群全体の基準となるY座標 (地面基準のbottom)
    // 衝突判定やロジックで使う代表的な幅と高さ (partsの外接矩形などから計算しても良い)
    // 今回はシンプルにプリセットのbaseTotalWidth/Heightを使う
    colliderWidth: number;
    colliderHeight: number;
    parts: Array<{ // 描画用の各パーツ情報
        renderX: number; // 親のXからの相対ではなく、画面上の絶対X
        renderY: number; // 親のYからの相対ではなく、画面上の絶対Y (bottom基準)
        width: number;
        height: number;
        color: string;
        offsetX: number;
        offsetY: number;
    }>;
}
const obstacles = reactive<ObstacleInstance[]>([]);
let nextObstacleId = 0;

// --- ゲームの状態 ---
const gameStarted = ref(false);
const gameOver = ref(false); // ゲームオーバー状態
let gameLoopId: number | null = null;
const score = ref(0); // スコア

// --- プレイヤーのバウンディングボックス (衝突判定用) ---
const playerRect = computed(() => ({
    left: playerX,
    right: playerX + playerWidth,
    top: gameContainerHeight - playerY.value - playerHeight, //画面上部からのY座標
    bottom: gameContainerHeight - playerY.value,         //画面上部からのY座標
}));

// --- プレイヤーのスタイルを動的に変更するために left は固定値として template へ ---

// --- ジャンプ処理 ---
function performJump(power: number) { // ジャンプ力を引数で受け取るように変更
    if (!isJumping.value && gameStarted.value && !gameOver.value) {
        isJumping.value = true;
        playerVelocityY.value = power; // 受け取った力でジャンプ
    }
}

// --- ユーティリティ関数: 範囲内のランダムな数値 ---
function getRandomInRange(min: number, max: number) {
    return Math.random() * (max - min) + min;
}
function getRandomColor(colors: string[]): string {
    return colors[Math.floor(Math.random() * colors.length)];
}

// --- 障害物生成 ---
function spawnObstacle() {
    const totalWeight = Object.values(obstaclePresets).reduce((sum, preset) => sum + preset.spawnWeight, 0);
    let randomWeight = Math.random() * totalWeight;
    let selectedPresetType: ObstaclePresetType | null = null;

    for (const type in obstaclePresets) {
        const T = parseInt(type) as ObstaclePresetType;
        // hasOwnProperty のチェックは数値キーの enum の場合、文字列キーとして扱われるため、このままでも動作します
        if (obstaclePresets.hasOwnProperty(T)) { // または Object.prototype.hasOwnProperty.call(obstaclePresets, T)
            if (randomWeight < obstaclePresets[T].spawnWeight) {
                selectedPresetType = T;
                break;
            }
            randomWeight -= obstaclePresets[T].spawnWeight;
        }
    }

    if (selectedPresetType === null) {
        console.warn("Fallback to SingleLow as selectedPresetType was null. Check spawnWeights if this is unexpected.");
        selectedPresetType = ObstaclePresetType.SingleLow; // フォールバック
    }

    const preset = obstaclePresets[selectedPresetType];
    if (!preset) {
        console.error(`FATAL: Preset for type ${ObstaclePresetType[selectedPresetType]} (enum value ${selectedPresetType}) is undefined in obstaclePresets. Please check obstaclePresets definition.`);
        return; // プリセットが見つからない場合は処理を中断
    }

    let yPosition = groundHeight;
    if (preset.canBeFloating && preset.minYOffset !== undefined && preset.maxYOffset !== undefined) {
        yPosition = groundHeight + getRandomInRange(preset.minYOffset, preset.maxYOffset);
    }

    console.log(`Attempting to spawn preset: ${ObstaclePresetType[selectedPresetType]}`);

    const generatedParts = preset.parts.map((blueprint, index) => {
        if (!blueprint) {
            console.error(`Blueprint at index ${index} for preset ${ObstaclePresetType[selectedPresetType!]} is undefined.`);
            return { offsetX: 0, offsetY: 0, width: 10, height: 10, color: 'magenta', error: 'Undefined blueprint' };
        }

        // widthRange のチェック
        if (!blueprint.widthRange || !Array.isArray(blueprint.widthRange) || blueprint.widthRange.length < 2) {
            console.error(`Blueprint ${index} (offsetX: ${blueprint.offsetX}) for preset ${ObstaclePresetType[selectedPresetType!]} has invalid or missing widthRange. Actual value:`, blueprint.widthRange);
            // エラー発生源の特定のため、エラーを投げて停止させるか、フォールバック値で続行するか選択
            // throw new Error(`Invalid widthRange for preset ${ObstaclePresetType[selectedPresetType!]}, part index ${index}`);
            return { offsetX: blueprint.offsetX || 0, offsetY: blueprint.offsetY || 0, width: 10, height: 10, color: 'purple', error: 'Invalid widthRange' };
        }
        // heightRange のチェック
        if (!blueprint.heightRange || !Array.isArray(blueprint.heightRange) || blueprint.heightRange.length < 2) {
            console.error(`Blueprint ${index} (offsetX: ${blueprint.offsetX}) for preset ${ObstaclePresetType[selectedPresetType!]} has invalid or missing heightRange. Actual value:`, blueprint.heightRange);
            return { offsetX: blueprint.offsetX || 0, offsetY: blueprint.offsetY || 0, width: 10, height: 10, color: 'orange', error: 'Invalid heightRange' };
        }
        // colorOptions のチェック
        if (!blueprint.colorOptions || !Array.isArray(blueprint.colorOptions) || blueprint.colorOptions.length === 0) {
            console.error(`Blueprint ${index} (offsetX: ${blueprint.offsetX}) for preset ${ObstaclePresetType[selectedPresetType!]} has invalid or missing colorOptions. Actual value:`, blueprint.colorOptions);
            return { offsetX: blueprint.offsetX || 0, offsetY: blueprint.offsetY || 0, width: 10, height: 10, color: 'cyan', error: 'Invalid colorOptions' };
        }

        const width = getRandomInRange(blueprint.widthRange[0], blueprint.widthRange[1]);
        const height = getRandomInRange(blueprint.heightRange[0], blueprint.heightRange[1]);
        const color = getRandomColor(blueprint.colorOptions);
        return {
            offsetX: blueprint.offsetX,
            offsetY: blueprint.offsetY,
            width: width,
            height: height,
            color: color,
        };
    });

    // エラーがあったパーツを除外 (エラープロパティを持つものを除外)
    const validGeneratedParts = generatedParts.filter(part => !part.hasOwnProperty('error'));

    if (validGeneratedParts.length !== generatedParts.length) {
        console.warn(`Some parts were invalid and have been filtered out for preset ${ObstaclePresetType[selectedPresetType!]}.`);
    }

    // 描画する有効なパーツがない場合はインスタンスを生成しない (ただし元々パーツがないプリセットは除く)
    if (validGeneratedParts.length === 0 && preset.parts.length > 0) {
        console.error(`No valid parts could be generated for preset ${ObstaclePresetType[selectedPresetType!]}. Skipping obstacle spawn.`);
        return;
    }

    const newObstacleInstance: ObstacleInstance = {
        id: nextObstacleId++,
        presetType: selectedPresetType,
        x: gameContainerWidth,
        y: yPosition,
        colliderWidth: preset.baseTotalWidth,
        colliderHeight: preset.baseTotalHeight,
        parts: validGeneratedParts.map(generatedPart => ({
            renderX: gameContainerWidth + (generatedPart.offsetX || 0), // offsetX がない場合に備える
            renderY: yPosition + (generatedPart.offsetY || 0), // offsetY がない場合に備える
            width: generatedPart.width,
            height: generatedPart.height,
            color: generatedPart.color,
            offsetX: generatedPart.offsetX || 0,
            offsetY: generatedPart.offsetY || 0,
        })),
    };

    // パーツがあるインスタンスのみ追加 (または元々パーツ定義がなかったプリセット)
    if (newObstacleInstance.parts.length > 0 || preset.parts.length === 0) {
        obstacles.push(newObstacleInstance);
        console.log('Spawned Instance:', ObstaclePresetType[selectedPresetType], newObstacleInstance);
    } else if (preset.parts.length > 0) { // 元々パーツがあるはずなのに全て無効になった場合
        console.warn(`Obstacle instance for ${ObstaclePresetType[selectedPresetType!]} was not pushed because it had no valid parts after filtering.`);
    }
}

// --- 衝突判定 ---
function checkCollision() {
    for (const obstacle of obstacles) {
        // 障害物全体のバウンディングボックスで判定
        const obstacleRect = {
            left: obstacle.x,
            right: obstacle.x + obstacle.colliderWidth, // colliderWidth を使用
            // colliderHeight と obstacle.y (基準Y) で衝突判定
            // obstacle.y は障害物群の「底辺」のY座標と考える
            top: gameContainerHeight - obstacle.y - obstacle.colliderHeight,
            bottom: gameContainerHeight - obstacle.y,
        };

        if (
            playerRect.value.left < obstacleRect.right &&
            playerRect.value.right > obstacleRect.left &&
            playerRect.value.top < obstacleRect.bottom &&
            playerRect.value.bottom > obstacleRect.top
        ) {
            return true;
        }
    }
    return false;
}

// --- ゲームループ ---
function gameLoop(currentTime: number) { // currentTime を引数に追加
    if (!gameStarted.value || gameOver.value) { // gameOver時もループ停止
        if (gameOver.value && gameLoopId) { // ゲームオーバーなら明示的に止める
            cancelAnimationFrame(gameLoopId);
            gameLoopId = null;
        }
        return;
    }

    // ジャンプチャージ状態の更新 (チャージバー用) <--- 追加
    if (isChargingJump.value) {
        const chargeDuration = performance.now() - jumpChargeStartTime;
        currentJumpChargeRatio.value = Math.min(chargeDuration / jumpChargeTimeMax, 1);
    } else {
        currentJumpChargeRatio.value = 0; // チャージしてなければ0
    }

    // プレイヤーのY座標更新
    playerY.value += playerVelocityY.value;
    if (playerY.value > groundHeight || isJumping.value) { //重力
        playerVelocityY.value -= gravity;
    }

    // 地面に着地したかの判定

    if (playerY.value <= groundHeight) {
        playerY.value = groundHeight;
        playerVelocityY.value = 0;
        isJumping.value = false;
    }

    // (オプション) 天井衝突判定
    // const ceiling = gameContainerHeight - playerHeight;
    // if (playerY.value >= ceiling) {
    //   playerY.value = ceiling;
    //   playerVelocityY.value = 0; // 天井に当たったら速度0 (跳ね返りなし)
    // }

    // 地面のスクロール
    groundScrollX.value -= scrollSpeed.value;

    // (オプション) スクロール位置が大きくなりすぎないようにリセット
    // 例えば、地面の模様の繰り返し幅が100pxなら
    // if (groundScrollX.value <= -100) {
    //   groundScrollX.value += 100;
    // }
    // 今回は背景画像を使うので、単純に減らし続けるだけでもOK

    // 障害物の管理とスクロール
    // 1. 新しい障害物の生成
    if (currentTime >= nextSpawnTime) {
        spawnObstacle(); // 最初の障害物を生成

        if (consecutiveSpawnCount < maxConsecutiveSpawns && Math.random() < 0.4) { // 40%の確率で連続出現
            // 次の連続出現時間を短く設定
            nextSpawnTime = currentTime + consecutiveSpawnInterval + getRandomInRange(-50, 50); // 少し間隔を揺らす
        } else {
            // 通常の出現間隔を設定し、連続出現カウントをリセット
            const interval = baseObstacleSpawnIntervalMin + Math.random() * (baseObstacleSpawnIntervalMax - baseObstacleSpawnIntervalMin);
            nextSpawnTime = currentTime + interval;
            consecutiveSpawnCount = 0;
        }
    }

    // 2. 障害物の移動と画面外判定 (scrollSpeed.value を使用)
    for (let i = obstacles.length - 1; i >= 0; i--) {
        const obstacleInst = obstacles[i];
        obstacleInst.x -= scrollSpeed.value; // 親障害物のX座標を移動

        // 各パーツの描画用X座標も更新
        // const preset = obstaclePresets[obstacleInst.presetType]; // 不要になる
        obstacleInst.parts.forEach((part) => { // index も不要
            // part に offsetX が含まれているのでそれを使う
            part.renderX = obstacleInst.x + part.offsetX;
            // Y座標は親のYとパーツのoffsetYで決まり、スクロールでは変わらない
            // part.renderY = obstacleInst.y + part.offsetY; // 生成時に計算済み
        });
        if (obstacleInst.x + obstacleInst.colliderWidth < 0) { // colliderWidth を使用
            obstacles.splice(i, 1);
            if (!gameOver.value) { score.value += 10; }
        }
    }


    // 衝突判定
    if (checkCollision()) {
        gameOver.value = true;
        // gameLoopId はこの関数の最後で requestAnimationFrame を呼ぶ前に止める
        // もしくは、次のフレームで gameOver.value が true なのでループの最初で止まる
        console.log("GAME OVER!");
        // ここでゲームオーバ時の音を鳴らしたり、特別な演出を入れることもできる
    }

    // スコア加算 (時間経過でも少し加算するなら)
    // score.value += 1;

    if (!gameOver.value) { // ゲームオーバーでなければ次のフレームを要求
        gameLoopId = requestAnimationFrame(gameLoop);
    }
}

// --- キーボードイベント ---
function handleKeydown(event: KeyboardEvent) {
    if (event.code === 'Space') {
        event.preventDefault();
        if (!gameStarted.value) {
            startGame();
        } else if (!gameOver.value && !isJumping.value && !isChargingJump.value) {
            isChargingJump.value = true;
            jumpChargeStartTime = performance.now();
            currentJumpChargeRatio.value = 0; // チャージ開始時は0
        }
    }
}

function handleKeyup(event: KeyboardEvent) {
    if (event.code === 'Space') {
        if (isChargingJump.value && gameStarted.value && !gameOver.value) {
            const chargeDuration = performance.now() - jumpChargeStartTime;
            isChargingJump.value = false;
            // currentJumpChargeRatio.value は gameLoop で更新されるが、即時ジャンプのためにここで計算
            const chargeRatio = Math.min(chargeDuration / jumpChargeTimeMax, 1);
            const jumpForce = minJumpPower + (maxJumpPower - minJumpPower) * chargeRatio;
            performJump(jumpForce);
            // currentJumpChargeRatio.value = 0; // ジャンプ後はリセット (gameLoopでも行われる)
        }
    }
}

// --- 画面クリック/タップイベント
function handleScreenInteractionStart() {
    if (!gameStarted.value) {
        startGame();
    } else if (!gameOver.value && !isJumping.value && !isChargingJump.value) {
        isChargingJump.value = true;
        jumpChargeStartTime = performance.now();
        currentJumpChargeRatio.value = 0;
    }
}

function handleScreenInteractionEnd() {
    if (isChargingJump.value && gameStarted.value && !gameOver.value) {
        const chargeDuration = performance.now() - jumpChargeStartTime;
        isChargingJump.value = false;
        const chargeRatio = Math.min(chargeDuration / jumpChargeTimeMax, 1);
        const jumpForce = minJumpPower + (maxJumpPower - minJumpPower) * chargeRatio;
        performJump(jumpForce);
        // currentJumpChargeRatio.value = 0;
    }
}

// --- ゲーム開始/リトライ処理 ---
function startGame() {
    if (gameStarted.value && !gameOver.value) return;
    gameStarted.value = true;
    gameOver.value = false; // ゲームオーバー状態をリセット
    playerY.value = groundHeight;
    playerVelocityY.value = 0;
    isJumping.value = false;
    isChargingJump.value = false;
    currentJumpChargeRatio.value = 0;
    groundScrollX.value = 0;
    obstacles.length = 0; // 障害物配列を空にする
    nextObstacleId = 0;
    consecutiveSpawnCount = 0; // 連続出現カウント
    score.value = 0; // スコアをリセット
    // 最初の障害物の出現時間を設定
    const initialInterval = baseObstacleSpawnIntervalMin + Math.random() * (baseObstacleSpawnIntervalMax - baseObstacleSpawnIntervalMin);
    nextSpawnTime = performance.now() + initialInterval + 500; // 最初の出現は少し間を置く

    if (gameLoopId) cancelAnimationFrame(gameLoopId); // 既存のループがあれば止める
    // requestAnimationFrame にはタイムスタンプが渡されるので、それを gameLoop に渡す
    gameLoopId = requestAnimationFrame(gameLoop);
}

// --- ライフサイクルフック ---
// 例: pages/index.vue の <script setup>
const gameContainerRef = ref<HTMLDivElement | null>(null); // <div class="game-container" ref="gameContainerRef"> と連携

onMounted(() => {
    window.addEventListener('keydown', handleKeydown);
    window.addEventListener('keyup', handleKeyup);

    if (gameContainerRef.value) { // gameContainerRef を使ったイベントリスナーなど
        gameContainerRef.value.addEventListener('mousedown', handleScreenInteractionStart);
        gameContainerRef.value.addEventListener('mouseup', handleScreenInteractionEnd);
        gameContainerRef.value.addEventListener('touchstart', handleScreenInteractionStart, { passive: false });
        gameContainerRef.value.addEventListener('touchend', handleScreenInteractionEnd);
    }
});

onUnmounted(() => {
    window.removeEventListener('keydown', handleKeydown);
    window.removeEventListener('keyup', handleKeyup);

    if (gameContainerRef.value) {
        gameContainerRef.value.removeEventListener('mousedown', handleScreenInteractionStart);
        gameContainerRef.value.removeEventListener('mouseup', handleScreenInteractionEnd);
        gameContainerRef.value.removeEventListener('touchstart', handleScreenInteractionStart);
        gameContainerRef.value.removeEventListener('touchend', handleScreenInteractionEnd);
    }
    if (gameLoopId) {
        cancelAnimationFrame(gameLoopId);
    }
});

</script>

<style scoped>
.game-container {
    width: 800px;
    height: 400px;
    /* gameContainerHeight と合わせる */
    border: 1px solid black;
    margin: 50px auto;
    position: relative;
    overflow: hidden;
    background-color: #87CEEB;
    cursor: pointer;
    /* クリック可能であることを示す */
}

.player {
    width: 50px;
    /* playerHeight と合わせる */
    height: 50px;
    /* playerHeight と合わせる */
    background-color: red;
    position: absolute;
    /* left: 100px; は template 側の :style で指定 */
}

.charge-bar-container {
    /* チャージバーのコンテナ */
    position: absolute;
    left: 0;
    /* bottom は template の :style で調整 */
    width: 100%;
    /* プレイヤーの幅に合わせる */
    height: 8px;
    /* チャージバーの高さ */
    background-color: rgba(255, 255, 255, 0.3);
    /* バーの背景 */
    border: 1px solid rgba(0, 0, 0, 0.5);
    border-radius: 4px;
    overflow: hidden;
    /* fillがはみ出ないように */
}

.charge-bar-fill {
    /* チャージバーの充填部分 */
    height: 100%;
    background-color: yellow;
    /* チャージの色 */
    border-radius: 3px;
    /* 少し丸みをつける */
    transition: width 0.05s linear;
    /* 幅の変化を滑らかに (任意) */
}

.ground {
    width: 100%;
    height: 50px;
    /* groundHeight と合わせる */
    /* background-color: green; */
    background-image: linear-gradient(to right,
            #654321 50%,
            /* 濃い茶色 */
            #8B4513 50%
            /* 薄い茶色 (SaddleBrown) */
        );
    /* 簡単な縞模様 */
    background-size: 40px 100%;
    /* 縞模様の幅と高さ */
    background-repeat: repeat-x;
    /* 横方向に繰り返す */
    position: absolute;
    bottom: 0;
    left: 0;
}


.obstacle {
    /* 障害物のスタイルを追加 */
    position: absolute;
    /* left, bottom, width, height は template 側の :style で指定 */
}

.obstacle-part {
    position: absolute;
    /* left, bottom, width, height, backgroundColor は template 側の :style で指定 */
}


.score-display {
    /* スコア表示のスタイルを追加 */
    position: absolute;
    top: 10px;
    left: 10px;
    font-size: 24px;
    color: white;
    text-shadow: 1px 1px 2px black;
}

.message-overlay {
    /* メッセージ表示用のオーバーレイ */
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background-color: rgba(0, 0, 0, 0.7);
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    color: white;
    text-align: center;
    z-index: 10;
    /* 他の要素より手前に表示 */
}

.message-overlay h1 {
    font-size: 48px;
    margin-bottom: 20px;
}

.message-overlay h2 {
    font-size: 36px;
    margin-bottom: 15px;
}

.message-overlay p {
    font-size: 20px;
    margin-bottom: 25px;
}

.message-overlay button {
    padding: 10px 20px;
    font-size: 18px;
    cursor: pointer;
    border: none;
    border-radius: 5px;
    background-color: #4CAF50;
    color: white;
}

.message-overlay button:hover {
    background-color: #45a049;
}
</style>