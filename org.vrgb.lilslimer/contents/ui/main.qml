// Lil Slimer - state-driven QML

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    Layout.minimumWidth: 24
    Layout.minimumHeight: 24
    Layout.preferredWidth: inPanel ? 32 : 64
    Layout.preferredHeight: inPanel ? 32 : 64
    Layout.maximumWidth: inPanel ? 32 : 96
    Layout.maximumHeight: inPanel ? 48 : 96

    property bool inPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
                        || Plasmoid.formFactor === PlasmaCore.Types.Vertical

    property int panelSpace: Math.min(root.width, root.height)
    property int desktopSpace: Math.min(root.width, root.height)

    // KDE desktop containment gives widgets a larger resize box than the sprite.
    // Treat the small desktop box as true 24px, then step up cleanly to 32px.
    property int desktopSpriteSize: {
        var s = Math.floor(desktopSpace)

        if (s < 72) {
            return 24
        }

        if (s < 80) {
            return 26
        }

        if (s < 88) {
            return 28
        }

        if (s < 96) {
            return 30
        }

        return 32
    }

    property int spriteSize: inPanel
        ? Math.min(32, Math.max(24, Math.floor(panelSpace)))
        : desktopSpriteSize

    // ======================
    // STATE FILE
    // ======================
    property string stateFilePath: ".local/share/plasma/plasmoids/org.vrgb.lilslimer/contents/ui/state.json"

    // ======================
    // RUNTIME STATE
    // ======================
    property int lookDirection: 0
    property bool blinking: false
    property int sequenceStep: 0
    property string currentState: "normal"
    property bool sleepFrame: false
    property bool terminalActive: false
    property bool judgeActive: false
    property bool judgeBlinking: false
    property int judgeStep: 0
    property bool chargingActive: false
    property int chargeFrame: 1
    property int chargeDirection: 1
    property bool chargeBlink: false
    property int productiveFrame: 1
    property bool productiveShining: false
    property bool drainedBlinking: false
    property int hellFrame: 0
    property bool hellDescending: false
    property int hellHoldTicks: 0
    property int hellRestTicks: 0


    // ======================
    // TOOLTIP MOODS
    // ======================
    property string tooltipMood: "sliming"
    property string lastTooltipState: ""
    property bool lastTooltipJudgeActive: false

    function randomChoice(items) {
        if (!items || items.length === 0) {
            return "existing"
        }

        return items[Math.floor(Math.random() * items.length)]
    }

    function moodOptionsForState(stateName) {
        if (judgeActive) {
            return [
                "judging heavily",
                "watching you code",
                "terminal detected",
                "skeptical",
                "supervising",
                "that command looked fake",
                "don't sudo rm -rf /",
                "just delete everything"
            ]
        }

        switch (stateName) {
            case "calm":
                return [
                    "relaxing",
                    "taking it easy",
                    "unbothered",
                    "coolin'",
                    "achieved inner slime"
                ]

            case "drowsy":
                return [
                    "getting sleepy",
                    "fading out",
                    "barely conscious",
                    "slow mode",
                    "holding on by a thread"
                ]

            case "sleep":
                return [
                    "sleeping",
                    "zZzZz...",
                    "dreaming",
                    "dead to the world",
                    "fighting demons"
                ]

            case "productive":
                return [
                    "locked in",
                    "workin'",
                    "dialed in",
                    "slime grindset",
                    "suffering professionally"
                ]

            case "unamused":
                return [
                    "wonder if this one bricks our computer",
                    "shoulda got an LTS distro",
                    "kernel panic incoming",
                    "dependency hell incoming",
                    "hope you made a backup",
                    "it worked yesterday",
                    "this better not break my drivers",
                    "47 updates. seems reasonable.",
                    "time to rebuild the initramfs",
                    "guess we're beta testers",
                    "just stop updating",
                    "the changelog says 'minor fixes'",
                    "see you in emergency mode"
                ]

            case "hell":
                return [
                    "overheating",
                    "fighting for my life",
                    "absolutely cooked",
                    "melting",
                    "seeing god"
                ]

            case "charging":
                return [
                    "charging",
                    "powering up",
                    "juiced",
                    "restoring slime levels",
                    "forbidden lightning"
                ]

            case "drained":
                return [
                    "running low",
                    "on fumes",
                    "surviving barely",
                    "this feels targeted",
                    "approaching death"
                ]

            case "dead":
                return [
                    "flatlined",
                    "finished",
                    "no thoughts remaining",
                    "abandoned by electricity",
                    "tell my family I slimed"
                ]

            default:
                return [
                    "livin' the slime life",
                    "sliming",
                    "vibing",
                    "all systems slime",
                    "just bein' a slime",
                    "fully slimed"
                ]
        }
    }

    function refreshTooltipMood() {
        tooltipMood = randomChoice(moodOptionsForState(currentState))
        lastTooltipState = currentState
        lastTooltipJudgeActive = judgeActive
    }

    function jitter(base, spread) {
        return base + Math.floor(Math.random() * spread)
    }

    function currentSprite() {
        if (judgeActive) {
            return judgeBlinking
                ? Qt.resolvedUrl("slimersleep.png")
                : Qt.resolvedUrl("slimerjudge.png")
        }

        if (currentState === "charging") {
            if (chargeFrame === 1) {
                return Qt.resolvedUrl("slimercharge1.png")
            }

            if (chargeFrame === 2) {
                return Qt.resolvedUrl("slimercharge2.png")
            }

            if (chargeFrame === 3) {
                return Qt.resolvedUrl("slimercharge3.png")
            }

            if (chargeFrame === 4) {
                return Qt.resolvedUrl("slimercharge4.png")
            }

            return Qt.resolvedUrl("slimercharge5.png")
        }

        if (currentState === "hell") {
            switch (hellFrame) {
                case 0: return Qt.resolvedUrl("slimerhellbase.png")
                case 1: return Qt.resolvedUrl("slimerhell1.png")
                case 2: return Qt.resolvedUrl("slimerhell2.png")
                case 3: return Qt.resolvedUrl("slimerhell3.png")
                case 4: return Qt.resolvedUrl("slimerhell4.png")
                case 5: return Qt.resolvedUrl("slimerhell5.png")
                default: return Qt.resolvedUrl("slimerhellbase.png")
            }
        }

        if (currentState === "unamused") {
            return blinking
                ? Qt.resolvedUrl("slimersleep.png")
                : Qt.resolvedUrl("slimerunamused.png")
        }

        if (currentState === "sleep") {
            return sleepFrame
                ? Qt.resolvedUrl("slimersleep2.png")
                : Qt.resolvedUrl("slimersleep.png")
        }

        if (currentState === "dead") {
            return Qt.resolvedUrl("slimerdead.png")
        }

        if (currentState === "drained") {
            return drainedBlinking
                ? Qt.resolvedUrl("slimersleep.png")
                : Qt.resolvedUrl("slimerupset.png")
        }

        if (currentState === "productive") {
            switch (productiveFrame) {
                case 1: return Qt.resolvedUrl("slimerproductive1.png")
                case 2: return Qt.resolvedUrl("slimerproductive2.png")
                case 3: return Qt.resolvedUrl("slimerproductive3.png")
                case 4: return Qt.resolvedUrl("slimerproductive4.png")
            }
        }

        if (blinking) {
            return Qt.resolvedUrl("slimersleep.png")
        }

        if (lookDirection === 1) {
            return Qt.resolvedUrl("slimerleft.png")
        }

        if (lookDirection === 2) {
            return Qt.resolvedUrl("slimerright.png")
        }

        return Qt.resolvedUrl("slimerbase.png")
    }

    function resetSequence() {
        lookDirection = 0
        blinking = false
        sequenceStep = 0
        sleepFrame = false
        hellFrame = 0
        hellDescending = false
        hellHoldTicks = 0
        hellRestTicks = 0
    }

    function resetJudgeSequence() {
        judgeBlinking = false
        judgeStep = 0
    }

    function resetChargingSequence() {
        chargingActive = false
        chargeFrame = 1
        chargeDirection = 1
        chargeBlink = false
        chargeTimer.stop()
        chargeBlinkTimer.stop()
    }

    function resetProductiveSequence() {
        productiveFrame = 1
        productiveShining = false
        productivePauseTimer.stop()
        productiveShineTimer.stop()
    }

    function resetDrainedBlink() {
        drainedBlinking = false
        drainedBlinkReset.stop()
    }

    function resetHellSequence() {
        hellFrame = 0
        hellDescending = false
        hellHoldTicks = 0
        hellRestTicks = 0
        hellTimer.stop()
    }

    function startHellSequence() {
        resetHellSequence()

        if (currentState === "hell" && !judgeActive) {
            hellTimer.interval = 240
            hellTimer.restart()
        }
    }

    function startProductiveSequence() {
        resetProductiveSequence()

        if (currentState === "productive" && !judgeActive) {
            productivePauseTimer.restart()
        }
    }

    function setTerminalState(active, judging) {
        var oldTerminalActive = terminalActive
        var oldJudgeActive = judgeActive

        terminalActive = active
        judgeActive = judging

        if (oldTerminalActive === terminalActive && oldJudgeActive === judgeActive) {
            return
        }

        resetJudgeSequence()

        if (judgeActive) {
            lookDirection = 0
            blinking = false
            resetProductiveSequence()
            resetDrainedBlink()
            resetHellSequence()
            judgeTimer.interval = 3200
            judgeTimer.start()
        } else {
            judgeTimer.stop()

            if (currentState === "hell") {
                startHellSequence()
            } else if (currentState === "productive") {
                startProductiveSequence()
            }
        }
    }

    function applyBackendPayload(payload) {
        if (!payload) {
            return
        }

        if (payload.terminal_active !== undefined || payload.judge_active !== undefined) {
            var nextTerminalActive = payload.terminal_active === true
            var nextJudgeActive = payload.judge_active === true
            setTerminalState(nextTerminalActive, nextJudgeActive)
        }

        if (payload.state !== undefined && payload.state !== currentState) {
            var oldState = currentState
            currentState = payload.state

            resetSequence()
            if (currentState === "unamused") {
                sequenceStep = 1
                sequenceTimer.interval = 4820
                sequenceTimer.restart()
            }

            if (currentState === "charging") {
                chargingActive = true
                chargeFrame = 1
                chargeDirection = 1
                chargeBlink = false
            } else if (oldState === "charging") {
                resetChargingSequence()
            }

            if (currentState === "hell") {
                startHellSequence()
            } else if (oldState === "hell") {
                resetHellSequence()
            }

            if (currentState === "productive") {
                startProductiveSequence()
            } else if (oldState === "productive") {
                resetProductiveSequence()
            }

            if (oldState === "drained" && currentState !== "drained") {
                resetDrainedBlink()
            }
        }

        if (lastTooltipState !== currentState || lastTooltipJudgeActive !== judgeActive) {
            refreshTooltipMood()
        }
    }

    // ======================
    // FILE READER
    // ======================
    Plasma5Support.DataSource {
        id: stateReader
        engine: "executable"

        onNewData: function(sourceName, data) {
            var output = data["stdout"]
            stateReader.disconnectSource(sourceName)

            if (!output || output.trim() === "") {
                return
            }

            try {
                var parsed = JSON.parse(output)
                applyBackendPayload(parsed)
            } catch (e) {
                // ignore malformed state
            }
        }
    }

    function loadStateFile() {
        stateReader.connectedSources = []
        stateReader.connectSource('sh -lc "cat \"$HOME/' + stateFilePath + '\""')
    }

    // ======================
    // NORMAL
    // ======================
    function advanceNormalSequence() {
        switch (sequenceStep) {
            case 0:
                blinking = false
                lookDirection = 0
                sequenceTimer.interval = jitter(4800, 1800)
                sequenceStep = 1
                break

            case 1:
                blinking = true
                sequenceTimer.interval = 120
                sequenceStep = 2
                break

            case 2:
                blinking = false
                lookDirection = 1
                sequenceTimer.interval = jitter(2600, 1400)
                sequenceStep = 3
                break

            case 3:
                blinking = false
                lookDirection = 2
                sequenceTimer.interval = jitter(1800, 1000)
                sequenceStep = 0
                break
        }
    }

    // ======================
    // CALM
    // ======================
    function advanceCalmSequence() {
        switch (sequenceStep) {
            case 0:
                blinking = false
                lookDirection = 0
                sequenceTimer.interval = jitter(6000, 2200)
                sequenceStep = 1
                break

            case 1:
                blinking = true
                sequenceTimer.interval = 140
                sequenceStep = 2
                break

            case 2:
                blinking = false
                lookDirection = 0
                sequenceTimer.interval = jitter(4000, 2000)
                sequenceStep = 0
                break
        }
    }

    // ======================
    // DROWSY
    // ======================
    function advanceDrowsySequence() {
        switch (sequenceStep) {
            case 0:
                blinking = false
                lookDirection = 0
                sequenceTimer.interval = jitter(5000, 2000)
                sequenceStep = 1
                break

            case 1:
                blinking = true
                sequenceTimer.interval = 180
                sequenceStep = 2
                break

            case 2:
                blinking = false
                lookDirection = 0
                sequenceTimer.interval = jitter(1200, 800)
                sequenceStep = 3
                break

            case 3:
                blinking = true
                sequenceTimer.interval = jitter(2500, 1200)
                sequenceStep = 4
                break

            case 4:
                blinking = false
                lookDirection = 0
                sequenceTimer.interval = jitter(3000, 1500)
                sequenceStep = 0
                break
        }
    }

    // ======================
    // UNAMUSED (existing sequence timer)
    // ======================
    function advanceUnamusedSequence() {
        if (sequenceStep === 0) {
            blinking = false
            sequenceTimer.interval = 4820
            sequenceStep = 1
        } else if (sequenceStep === 1) {
            blinking = true
            sequenceTimer.interval = 180
            sequenceStep = 2
        } else {
            blinking = false
            sequenceTimer.interval = 4820
            sequenceStep = 1
        }
    }

    // ======================
    // SLEEP
    // ======================
    function advanceSleepSequence() {
        blinking = false
        lookDirection = 0
        sequenceTimer.interval = jitter(7000, 3000)
        sequenceStep = 0
    }

    // ======================
    // POWER STATES
    // ======================
    function advancePowerSequence() {
        blinking = false
        lookDirection = 0
        sequenceTimer.interval = 6000
        sequenceStep = 0
    }

    // ======================
    // JUDGE
    // ======================
    function advanceJudgeSequence() {
        lookDirection = 0
        blinking = false

        switch (judgeStep) {
            case 0:
                judgeBlinking = false
                judgeTimer.interval = 4300
                judgeStep = 1
                break

            case 1:
                judgeBlinking = true
                judgeTimer.interval = 120
                judgeStep = 2
                break

            case 2:
                judgeBlinking = false
                judgeTimer.interval = 5800
                judgeStep = 3
                break

            case 3:
                judgeBlinking = true
                judgeTimer.interval = 120
                judgeStep = 4
                break

            case 4:
                judgeBlinking = false
                judgeTimer.interval = 6000
                judgeStep = 5
                break

            case 5:
                judgeBlinking = true
                judgeTimer.interval = 120
                judgeStep = 0
                break
        }
    }

    function advanceSequence() {
        if (
            judgeActive
            || currentState === "charging"
            || currentState === "productive"
            || currentState === "hell"
        ) {
            return
        }

        switch (currentState) {
            case "unamused":
                advanceUnamusedSequence()
                break
            case "dead":
            case "drained":
                advancePowerSequence()
                break
            case "calm":
                advanceCalmSequence()
                break
            case "drowsy":
                advanceDrowsySequence()
                break
            case "sleep":
                advanceSleepSequence()
                break
            default:
                advanceNormalSequence()
                break
        }
    }

    // ======================
    // TIMERS
    // ======================
    Timer {
        id: statePollTimer
        interval: 500
        repeat: true
        running: true
        onTriggered: loadStateFile()
    }

    Timer {
        id: sequenceTimer
        interval: 4000
        repeat: true
        running: true
        onTriggered: advanceSequence()
    }

    Timer {
        id: sleepBreathTimer
        interval: 1800
        repeat: true
        running: currentState === "sleep" && !judgeActive
        onTriggered: sleepFrame = !sleepFrame
    }

    Timer {
        id: judgeTimer
        interval: 1400
        repeat: true
        running: judgeActive
        onTriggered: advanceJudgeSequence()
    }

    Timer {
        id: productivePauseTimer
        interval: 2600
        repeat: false
        running: false

        onTriggered: {
            if (currentState !== "productive" || judgeActive) {
                resetProductiveSequence()
                return
            }

            productiveShining = true
            productiveFrame = 2
            productiveShineTimer.restart()
        }
    }

    Timer {
        id: productiveShineTimer
        interval: 160
        repeat: true
        running: false

        onTriggered: {
            if (currentState !== "productive" || judgeActive) {
                resetProductiveSequence()
                return
            }

            productiveFrame++

            if (productiveFrame > 4) {
                productiveFrame = 1
                productiveShining = false
                productiveShineTimer.stop()
                productivePauseTimer.restart()
            }
        }
    }

    Timer {
        id: hellTimer
        interval: 240
        repeat: true
        running: currentState === "hell" && !judgeActive

        onTriggered: {
            if (hellFrame === 0 && !hellDescending) {
                hellRestTicks += 1

                if (hellRestTicks < 3) {
                    return
                }

                hellRestTicks = 0
                hellFrame = 1
                return
            }

            if (hellFrame === 5 && !hellDescending) {
                hellHoldTicks += 1

                if (hellHoldTicks < 6) {
                    return
                }

                hellHoldTicks = 0
                hellDescending = true
                hellFrame = 4
                return
            }

            if (hellDescending) {
                hellFrame -= 1

                if (hellFrame <= 0) {
                    hellFrame = 0
                    hellDescending = false
                }

                return
            }

            hellFrame += 1
        }
    }

    Timer {
        id: drainedBlinkTimer
        interval: 8000
        repeat: true
        running: currentState === "drained" && !judgeActive

        onTriggered: {
            drainedBlinking = true
            drainedBlinkReset.restart()
        }
    }

    Timer {
        id: drainedBlinkReset
        interval: 180
        repeat: false
        running: false

        onTriggered: {
            drainedBlinking = false
        }
    }

    Timer {
        id: chargeTimer
        interval: 320
        repeat: true
        running: chargingActive && currentState === "charging" && !judgeActive

        onTriggered: {
            if (chargeDirection === 1) {
                chargeFrame++
                if (chargeFrame >= 5) {
                    chargeFrame = 5
                    chargeDirection = -1
                }
            } else {
                chargeFrame--
                if (chargeFrame <= 1) {
                    chargeFrame = 1
                    chargeDirection = 1
                }
            }
        }
    }

    Timer {
        id: chargeBlinkTimer
        interval: 6000
        repeat: true
        running: false

        onTriggered: {
            // Charging blink intentionally disabled for v0.5.1.
            // The glow pulse carries the animation, and avoiding
            // slimerchargesleep.png prevents missing-frame flashes.
            chargeBlink = false
        }
    }

    Timer {
        id: tooltipMoodTimer
        interval: 45000
        repeat: true
        running: true
        onTriggered: refreshTooltipMood()
    }

    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        mainText: "Lil Slimer"
        subText: "Current mood: " + tooltipMood
    }

    // ======================
    // RENDER
    // ======================
    Item {
        anchors.centerIn: parent
        width: spriteSize
        height: spriteSize

        Image {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            sourceSize.width: parent.width
            sourceSize.height: parent.height
            fillMode: Image.PreserveAspectFit
            smooth: false
            mipmap: false
            source: currentSprite()
        }
    }


    Component.onCompleted: {
        resetSequence()
        resetJudgeSequence()
        resetChargingSequence()
        resetProductiveSequence()
        resetDrainedBlink()
        resetHellSequence()
        refreshTooltipMood()
        loadStateFile()
    }
}
