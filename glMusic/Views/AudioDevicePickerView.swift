//
//  AudioDevicePickerView.swift
//  glMusic
//
//  Created by go love on 11/7/26.
//

import SwiftUI

/// 音频输出设备选择浮层视图
struct AudioDevicePickerView: View {
    @Environment(ThemeManager.self) private var themeManager
    private var deviceManager = AudioDeviceManager.shared
    var onSelect: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部标题与当前活跃设备提示
            HStack(spacing: 8) {
                Image(systemName: "airplayaudio")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(themeManager.accentColor)

                Text("播放设备".localized)
                    .font(.headline)

                Spacer()

                if let current = deviceManager.currentDevice {
                    Text(current.transportDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("选择音频输出目标，声音将实时切换至所选设备".localized)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // 可用设备列表
            VStack(spacing: 4) {
                ForEach(deviceManager.outputDevices) { device in
                    let isSelected = device.id == deviceManager.currentDeviceID
                    Button {
                        deviceManager.selectDevice(device)
                        onSelect?()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: device.iconName)
                                .font(.system(size: 15))
                                .foregroundStyle(isSelected ? themeManager.accentColor : .secondary)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.name)
                                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                                    .foregroundStyle(isSelected ? themeManager.accentColor : .primary)
                                    .lineLimit(1)

                                Text(device.transportDescription)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(themeManager.accentColor)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? themeManager.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? themeManager.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // 底部操作：快捷打开系统偏好设置的声音面板
            Button {
                deviceManager.openSystemSoundSettings()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                    Text("声音偏好设置...".localized)
                        .font(.system(size: 11))
                    Spacer()
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 270)
        .onAppear {
            deviceManager.refreshDevices()
        }
    }
}

/// 放置在 PlayerBar 与 LyricsView 上的音频设备切换按钮
struct AudioDevicePickerButton: View {
    enum Style {
        case playerBar
        case lyrics
    }

    var style: Style = .playerBar
    @Environment(ThemeManager.self) private var themeManager
    private var deviceManager = AudioDeviceManager.shared
    @State private var showPopover = false
    @State private var isHovered = false

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            switch style {
            case .playerBar:
                Image(systemName: deviceManager.buttonIconName)
                    .font(.system(size: 18))
                    .foregroundStyle(
                        showPopover ? themeManager.accentColor :
                        (deviceManager.currentDevice?.isBuiltIn == false ? themeManager.accentColor : (isHovered ? .primary : .secondary))
                    )
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())

            case .lyrics:
                Image(systemName: deviceManager.buttonIconName)
                    .font(.system(size: 20))
                    .foregroundStyle(
                        showPopover ? themeManager.accentColor :
                        (deviceManager.currentDevice?.isBuiltIn == false ? themeManager.accentColor : (isHovered ? .white : .white.opacity(0.7)))
                    )
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("播放设备 (当前: %@)".localized(with: deviceManager.currentDevice?.name ?? "内置扬声器".localized))
        .popover(isPresented: $showPopover, arrowEdge: style == .playerBar ? .top : .bottom) {
            AudioDevicePickerView {
                showPopover = false
            }
        }
    }
}

#Preview {
    AudioDevicePickerView()
        .environment(ThemeManager.shared)
}
