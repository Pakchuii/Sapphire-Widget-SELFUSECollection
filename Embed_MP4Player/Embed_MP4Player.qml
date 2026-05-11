import QtQuick 2.15
import QtQuick.Controls 2.15
//%IF_QT6 import QtQuick.Controls.Basic
import QtQuick.Layouts 1.15
//%IF_QT6 import QtQuick.Dialogs
//%IF_QT5 import QtQuick.Dialogs 1.3
//%IF_QT6 import QtMultimedia
//%IF_QT5 import QtMultimedia 5.15
//%IF_QT6 import Qt5Compat.GraphicalEffects
//%IF_QT5 import QtGraphicalEffects 1.15
import "@COMMON_IMPORT@"

/**
 * @brief MP4视频播放QML组件 (Windows 专属：提前截胡防闪烁版)
 */

SWidget {
    id: root

    property int globalRadius: unitRadius || 8
    property int globalMargin: 3
    
    // 视频相关属性
    property string videoPath: ""
    property bool hasVideo: videoPath !== ""

    globalRoundCornerEnabled: true

    fpsDisplayMode: SWidget.FpsDisplayMode.Never

    function getValidUrl(path) {
        if (!path) return "";
        if (path.indexOf("://") !== -1) return path;
        if (path.indexOf(":") === 1) return "file:///" + path.replace(/\\/g, "/");
        if (path.startsWith("/")) return "file://" + path;
        return path;
    }

    onUnitVisibleChanged: {
        console.log("组件可见性变化:", unitVisible)
        if (!unitVisible) {
            console.log("组件变为不可见，暂停视频播放")
            if (mediaPlayer.playbackState === MediaPlayer.PlayingState) {
                mediaPlayer.pause()
            }
        } else {
            console.log("组件变为可见，恢复视频播放")
            if (hasVideo && mediaPlayer.playbackState === MediaPlayer.PausedState) {
                mediaPlayer.play()
            }
        }
    }
    
    onVideoPathChanged: {
        console.log("=== 视频路径变化 ===")
        if (videoPath) {
            console.log("设置视频源并准备播放")
            if (errorText) errorText.visible = false
            if (mediaPlayer) mediaPlayer.play()
        } else {
            console.log("清除视频源")
            if (errorText) errorText.visible = false
        }
    }
    
    Component.onCompleted: {
        console.log("=== MP4视频播放组件加载完成 ===")
        registerPersistentProperty("videoPath", "")
        console.log("已注册持久化属性: videoPath")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        //%QT6_BEGIN
        FileDialog {
            id: videoFileDialog
            title: "选择视频文件"
            nameFilters: ["所有视频文件 (*.mp4 *.avi *.mov *.wmv)"]
            onAccepted: {
                root.videoPath = selectedFile.toString()
            }
        }
        //%QT6_END

        //%QT5_BEGIN
        FileDialog {
            id: videoFileDialog
            title: "选择视频文件"
            nameFilters: ["所有视频文件 (*.mp4 *.avi *.mov *.wmv)"]
            onAccepted: {
                root.videoPath = fileUrl.toString()
            }
        }
        //%QT5_END
   
        // 视频显示主容器
        Rectangle {
            id: videoContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Qt.rgba(0, 0, 0, 0.3)
            radius: root.globalRadius
            border.color: root.currentThemeColor
            border.width: 1
            clip: true 
            
            // 纯黑底色打底，防止任何极端情况下的漏光
            Rectangle {
                anchors.fill: parent
                color: "black"
                visible: root.hasVideo
            }
            
            MouseArea {
                id: videoMouseArea
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: false
                propagateComposedEvents: true
                
                onClicked: function(mouse) { mouse.accepted = false }
                onDoubleClicked: function(mouse) { mouse.accepted = false }
                onReleased: function(mouse) { mouse.accepted = false }
                
                onPressed: function(mouse) {
                    if(root.hasVideo) {
                        mouse.accepted = false
                        return
                    } else {
                        if(root.currentOperationMode != "edit"){
                            videoFileDialog.open()
                            mouse.accepted = true
                        } else {
                            mouse.accepted = false
                        }
                    }
                }

                // 【核心黑科技】：高频定时器“提前截胡”法
                // Windows 底层在视频播放到100%时会强制重置渲染管线导致黑屏。
                // 我们通过每30毫秒检测一次，在视频还差150毫秒结束时，强行拉回0秒。
                // 这样引擎永远不会触发销毁逻辑，实现画面秒切防黑屏！
                Timer {
                    interval: 30
                    running: root.hasVideo && mediaPlayer.playbackState === MediaPlayer.PlayingState
                    repeat: true
                    onTriggered: {
                        if (mediaPlayer.duration > 0 && mediaPlayer.position >= mediaPlayer.duration - 150) {
                            mediaPlayer.seek(0)
                        }
                    }
                }
                
                // ================== 多媒体层 ==================
                //%QT6_BEGIN
                MediaPlayer {
                    id: mediaPlayer
                    autoPlay: true
                    loops: MediaPlayer.Infinite // 作为兜底逻辑保留
                    source: root.getValidUrl(root.videoPath)
                    videoOutput: videoPlayer
                    audioOutput: AudioOutput {}

                    onMediaStatusChanged: {
                        if (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia) play()
                    }
                }
                VideoOutput {
                    id: videoPlayer
                    anchors.fill: parent
                    visible: root.hasVideo
                    fillMode: VideoOutput.PreserveAspectCrop
                }
                //%QT6_END

                //%QT5_BEGIN
                MediaPlayer {
                    id: mediaPlayer
                    autoPlay: true
                    loops: MediaPlayer.Infinite // 作为兜底逻辑保留
                    source: root.getValidUrl(root.videoPath)

                    onStatusChanged: {
                        if (status === MediaPlayer.LoadedMedia || status === MediaPlayer.BufferedMedia) play()
                    }
                }
                VideoOutput {
                    id: videoPlayer
                    anchors.fill: parent
                    visible: root.hasVideo
                    fillMode: VideoOutput.PreserveAspectCrop
                    source: mediaPlayer
                }
                //%QT5_END
                // ==============================================
     
                // 无视频时的提示
                Text {
                    anchors.centerIn: parent
                    text: root.currentOperationMode == "edit" ? "点击下方按钮选择MP4视频" : "点击此处或者下方按钮选择MP4视频"
                    color: "white"
                    font.pixelSize: 14
                    visible: !root.hasVideo
                    renderType: Text.NativeRendering
                    antialiasing: true
                    z: 10
                }
                
                // 错误提示
                Text {
                    id: errorText
                    anchors.centerIn: parent
                    color: "#FF6B6B"
                    font.pixelSize: 12
                    visible: root.hasVideo && mediaPlayer.errorString !== ""
                    text: mediaPlayer.errorString
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    width: parent.width - 20
                    z: 10
                }
            }
        }
        
        // 控制面板
        Rectangle {
            id: buttonContainer
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(70, buttonLayout.implicitHeight + 20)
            color: Qt.rgba(0, 0, 0, 0.7)
            radius: 6
            visible: (root.currentOperationMode || "desktop") == "edit"
            
            ColumnLayout {
                id: buttonLayout
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8
                
                // 视频选择按钮
                Button {
                    visible: (root.currentOperationMode || "desktop") == "edit"
                    id: selectVideoButton
                    text: root.hasVideo ? "更换视频文件" : "选择MP4视频文件"
                    Layout.fillWidth: true
                    
                    background: Rectangle {
                        color: selectVideoButton.pressed ? Qt.darker("#4CAF50", 1.3) : "#4CAF50"
                        radius: 4
                        border.color: "white"
                        border.width: 1
                    }
                    
                    contentItem: Text {
                        text: selectVideoButton.text
                        color: "white"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.NativeRendering
                        antialiasing: true
                    }
                    
                    onClicked: {
                        videoFileDialog.open()
                    }
                }
                
                // 清除视频按钮
                RowLayout {
                    Layout.fillWidth: true
                    
                    Button {
                        visible: (root.currentOperationMode || "desktop") == "edit" && root.hasVideo
                        id: clearButton
                        text: "清除视频"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        
                        background: Rectangle {
                            color: clearButton.pressed ? Qt.darker("#F44336", 1.3) : "#F44336"
                            radius: 4
                            border.color: "white"
                            border.width: 1
                        }
                        
                        contentItem: Text {
                            text: clearButton.text
                            color: "white"
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            renderType: Text.NativeRendering
                            antialiasing: true
                        }
                        
                        onClicked: {
                            root.videoPath = ""
                            console.log("清除视频文件")
                        }
                    }
                }
            }
        }
    }

    Component.onDestruction: {
        console.log("MP4视频播放组件即将销毁")
        if (mediaPlayer.playbackState === MediaPlayer.PlayingState) {
            mediaPlayer.stop()
        }
    }
    
    // 底层事件穿透防崩溃保护
    function mouseEntered() {
        if(root.unit && root.unit.logDebug) {
            root.unit.logDebug("MP4视频播放组件收到鼠标进入事件")
        }
    }
    
    function mouseLeft() {
        if(root.unit && root.unit.logDebug) root.unit.logDebug("鼠标离开MP4视频播放组件")
    }
    
    function singleClicked() {
        if(root.unit && root.unit.logDebug) root.unit.logDebug("MP4视频播放组件收到单击事件")
    }
    
    function doubleClicked() {
        console.log("MP4视频播放组件收到双击事件")
    }
}